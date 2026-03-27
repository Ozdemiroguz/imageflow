import 'dart:io';
import 'dart:isolate';
import 'dart:math' show sqrt;
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

import '../../../../core/utils/log.dart';
import '../../../../core/services/native_corner_detection_service.dart';

/// Document crop & enhancement service.
///
/// Pipeline:
/// 1. Try native corner detection → perspective correction (copyRectify)
/// 2. Fallback: ML Kit text block bounding boxes → axis-aligned crop
/// 3. Apply eco filter (grayscale + contrast + normalize)
class DocumentCropService {
  const DocumentCropService({
    required NativeCornerDetectionService cornerDetection,
  }) : _cornerDetection = cornerDetection;

  final NativeCornerDetectionService _cornerDetection;

  static const _tag = 'DocumentCrop';

  static const _debugCorners = false;

  /// Process a document image: detect corners → crop/rectify → filter → save.
  Future<void> processDocument({
    required String sourcePath,
    required String targetPath,
    RecognizedText? recognizedText,
  }) async {
    // Try native corner detection first
    final corners = await _cornerDetection.detectCorners(imagePath: sourcePath);

    if (corners != null) {
      Log.info('Using native corners for perspective correction.', tag: _tag);
      final sourceBytes = await File(sourcePath).readAsBytes();
      final cornerList = corners.toList();

      if (_debugCorners) {
        await Isolate.run(() {
          _drawDebugCorners(sourceBytes, cornerList, targetPath);
        });
        return;
      }

      await Isolate.run(() {
        _perspectiveCorrectAndFilter(sourceBytes, cornerList, targetPath);
      });
      return;
    }

    // Fallback: text block crop + filter
    Log.info('No native corners. Using text block crop fallback.', tag: _tag);
    final sourceBytes = await File(sourcePath).readAsBytes();

    if (recognizedText == null || recognizedText.blocks.isEmpty) {
      // No text blocks either — just apply eco filter to whole image
      await Isolate.run(() {
        _filterOnly(sourceBytes, targetPath);
      });
      return;
    }

    // Estimate document bounds from text blocks
    final crop = _estimateCropFromTextBlocks(recognizedText.blocks);

    await Isolate.run(() {
      _cropAndFilter(sourceBytes, crop, targetPath);
    });
  }

  /// Estimate crop region from ML Kit text blocks with 10% margin.
  static ({int left, int top, int right, int bottom}) _estimateCropFromTextBlocks(
    List<TextBlock> blocks,
  ) {
    var minLeft = double.infinity;
    var minTop = double.infinity;
    var maxRight = double.negativeInfinity;
    var maxBottom = double.negativeInfinity;

    for (final block in blocks) {
      final r = block.boundingBox;
      if (r.left < minLeft) minLeft = r.left;
      if (r.top < minTop) minTop = r.top;
      if (r.right > maxRight) maxRight = r.right;
      if (r.bottom > maxBottom) maxBottom = r.bottom;
    }

    final textWidth = maxRight - minLeft;
    final textHeight = maxBottom - minTop;
    final marginX = textWidth * 0.10;
    final marginY = textHeight * 0.10;

    return (
      left: (minLeft - marginX).round(),
      top: (minTop - marginY).round(),
      right: (maxRight + marginX).round(),
      bottom: (maxBottom + marginY).round(),
    );
  }
}

// ---------------------------------------------------------------------------
// Top-level helpers for Isolate compatibility
// ---------------------------------------------------------------------------

/// Debug: draw red dots on corners, no crop/filter. Save original with dots.
void _drawDebugCorners(
  Uint8List sourceBytes,
  List<({double x, double y})> corners,
  String targetPath,
) {
  final src = img.decodeImage(sourceBytes);
  if (src == null) {
    File(targetPath).writeAsBytesSync(sourceBytes);
    return;
  }

  final red = img.ColorRgba8(255, 0, 0, 255);
  const radius = 30;

  for (final corner in corners) {
    final cx = corner.x.round().clamp(0, src.width - 1);
    final cy = corner.y.round().clamp(0, src.height - 1);
    img.fillCircle(src, x: cx, y: cy, radius: radius, color: red);
  }

  // Draw lines between corners: TL→TR→BR→BL→TL
  final green = img.ColorRgba8(0, 255, 0, 255);
  for (var i = 0; i < corners.length; i++) {
    final p1 = corners[i];
    final p2 = corners[(i + 1) % corners.length];
    img.drawLine(
      src,
      x1: p1.x.round(),
      y1: p1.y.round(),
      x2: p2.x.round(),
      y2: p2.y.round(),
      color: green,
      thickness: 5,
    );
  }

  File(targetPath).writeAsBytesSync(img.encodeJpg(src, quality: 92));
}

/// Perspective correct using 4 corners + eco filter, then save.
void _perspectiveCorrectAndFilter(
  Uint8List sourceBytes,
  List<({double x, double y})> corners,
  String targetPath,
) {
  final src = img.decodeImage(sourceBytes);
  if (src == null) {
    File(targetPath).writeAsBytesSync(sourceBytes);
    return;
  }

  // corners: [topLeft, topRight, bottomRight, bottomLeft]
  final tl = corners[0];
  final tr = corners[1];
  final br = corners[2];
  final bl = corners[3];

  // Calculate output dimensions from corner distances
  final topW = _dist(tl, tr);
  final botW = _dist(bl, br);
  final leftH = _dist(tl, bl);
  final rightH = _dist(tr, br);
  final dstWidth = ((topW + botW) / 2).round().clamp(1, 8000);
  final dstHeight = ((leftH + rightH) / 2).round().clamp(1, 8000);

  final dst = img.Image(width: dstWidth, height: dstHeight);

  final rectified = img.copyRectify(
    src,
    topLeft: img.Point(tl.x, tl.y),
    topRight: img.Point(tr.x, tr.y),
    bottomLeft: img.Point(bl.x, bl.y),
    bottomRight: img.Point(br.x, br.y),
    interpolation: img.Interpolation.linear,
    toImage: dst,
  );

  File(targetPath).writeAsBytesSync(
    img.encodeJpg(_ecoFilter(rectified), quality: 92),
  );
}

/// Crop to region + eco filter, then save.
void _cropAndFilter(
  Uint8List sourceBytes,
  ({int left, int top, int right, int bottom}) crop,
  String targetPath,
) {
  final src = img.decodeImage(sourceBytes);
  if (src == null) {
    File(targetPath).writeAsBytesSync(sourceBytes);
    return;
  }

  final x = crop.left.clamp(0, src.width - 1);
  final y = crop.top.clamp(0, src.height - 1);
  final w = (crop.right - crop.left).clamp(1, src.width - x);
  final h = (crop.bottom - crop.top).clamp(1, src.height - y);

  final cropped = img.copyCrop(src, x: x, y: y, width: w, height: h);

  File(targetPath).writeAsBytesSync(
    img.encodeJpg(_ecoFilter(cropped), quality: 92),
  );
}

/// Apply eco filter to whole image, then save.
void _filterOnly(Uint8List sourceBytes, String targetPath) {
  final src = img.decodeImage(sourceBytes);
  if (src == null) {
    File(targetPath).writeAsBytesSync(sourceBytes);
    return;
  }
  File(targetPath).writeAsBytesSync(
    img.encodeJpg(_ecoFilter(src), quality: 92),
  );
}

/// Eco filter: grayscale → contrast boost → normalize.
img.Image _ecoFilter(img.Image src) {
  var result = img.grayscale(src);
  result = img.adjustColor(result, contrast: 1.5);
  result = img.normalize(result, min: 0, max: 255);
  return result;
}

/// Euclidean distance between two points.
double _dist(({double x, double y}) a, ({double x, double y}) b) {
  final dx = a.x - b.x;
  final dy = a.y - b.y;
  return sqrt(dx * dx + dy * dy);
}
