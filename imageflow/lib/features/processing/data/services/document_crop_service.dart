import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:document_scan/document_scan.dart' as ds;
import 'package:image/image.dart' as img;

import '../../../../core/models/normalized_corners.dart';
import '../../../../core/utils/log.dart';
import '../../domain/entities/recognized_text_data.dart';
import '../../domain/services/document_cropper.dart';

/// Document crop & enhancement service, powered by the document_scan package.
///
/// Pipeline:
/// 1. Detect corners + perspective-correct + filter via document_scan's
///    [ds.DocumentDetector] + [ds.DocumentProcessor] (the same engine used in
///    realtime), then write the result to the target path.
/// 2. Fallback (no document detected): ML Kit text-block bounding boxes →
///    axis-aligned crop, or a whole-image filter — glue with no package
///    equivalent, kept for images where the rectangle detector finds nothing.
class DocumentCropService implements DocumentCropper {
  const DocumentCropService({ds.DocumentDetector? detector})
    : _detector = detector;

  final ds.DocumentDetector? _detector;

  ds.DocumentDetector get _documentDetector =>
      _detector ?? ds.DocumentDetector();

  static const _tag = 'DocumentCrop';

  // Match the app's prior output exactly: JPEG quality 92, and the enhance
  // filter (grayscale + contrast + normalize) which is the package equivalent
  // of the old eco filter — so the corner path and the text-block fallback
  // produce the same treatment.
  static const _output = ds.ScanOutputFormat.jpeg(quality: 92);
  static const _filter = ds.ScanFilter.enhance;

  /// Process a document image: detect corners → crop/rectify → filter → save.
  @override
  Future<void> processDocument({
    required String sourcePath,
    required String targetPath,
    RecognizedTextData? recognizedText,
    NormalizedCorners? corners,
  }) async {
    // If corners are supplied (e.g. from the manual corner-adjust screen), use
    // them and skip detection; otherwise detect through the package (normalized
    // 0..1). A detection/channel error is not fatal — log and fall through to
    // the text-block crop fallback, matching the app's prior graceful
    // degradation.
    ds.DocumentCorners? packageCorners = corners?.toPackage();
    if (packageCorners == null) {
      try {
        packageCorners =
            await _documentDetector.detect(ds.ScanInput.file(sourcePath));
      } catch (e) {
        Log.warning(
          'Corner detection failed ($e); falling back to text-block crop.',
          tag: _tag,
        );
      }
    }

    if (packageCorners != null) {
      Log.info('Using package corners for perspective correction.', tag: _tag);
      // crop() perspective-corrects + filters and returns encoded bytes; we own
      // writing them to disk (the package is file-system agnostic). Run it in an
      // isolate so the warp + filter + JPEG encode stay off the UI thread, as
      // the app's own warp did.
      final detected = packageCorners;
      final scanned = await Isolate.run(
        () => const ds.DocumentProcessor().crop(
          ds.ScanInput.file(sourcePath),
          detected,
          filter: _filter,
          output: _output,
        ),
      );
      if (scanned != null) {
        await File(targetPath).writeAsBytes(scanned.bytes);
        return;
      }
      Log.warning('Package crop returned null; falling back.', tag: _tag);
    }

    // Fallback: text block crop + filter (no package equivalent — the package
    // needs corners to warp; here the rectangle detector found none).
    Log.info('No document corners. Using text block crop fallback.', tag: _tag);

    if (recognizedText == null || recognizedText.blockBoxes.isEmpty) {
      // No text blocks either — apply the same enhance filter to the whole
      // image. The package's applyFilter decodes → enhances → encodes off the
      // caller thread; we still wrap it in an isolate so the JPEG encode of a
      // full-size photo doesn't touch the UI isolate.
      final filtered = await Isolate.run(
        () => const ds.DocumentProcessor()
            .applyFilter(ds.ScanInput.file(sourcePath), _filter, output: _output),
      );
      if (filtered != null) {
        await File(targetPath).writeAsBytes(filtered.bytes);
      } else {
        // Undecodable source — preserve the app's prior behaviour of leaving
        // the original bytes at the target rather than failing the pipeline.
        await File(sourcePath).copy(targetPath);
      }
      return;
    }

    // Estimate document bounds from text blocks, then axis-aligned crop +
    // enhance. This stays hand-rolled: the package's only crop is a 4-corner
    // perspective warp, so a plain rectangle crop has no package entrypoint.
    final crop = _estimateCropFromTextBlocks(recognizedText.blockBoxes);
    final sourceBytes = await File(sourcePath).readAsBytes();

    await Isolate.run(() {
      _cropAndFilter(sourceBytes, crop, targetPath);
    });
  }

  /// Estimate crop region from text block bounding boxes with a 10% margin.
  static ({int left, int top, int right, int bottom})
  _estimateCropFromTextBlocks(List<TextBlockBox> blocks) {
    var minLeft = double.infinity;
    var minTop = double.infinity;
    var maxRight = double.negativeInfinity;
    var maxBottom = double.negativeInfinity;

    for (final box in blocks) {
      if (box.left < minLeft) minLeft = box.left.toDouble();
      if (box.top < minTop) minTop = box.top.toDouble();
      if (box.right > maxRight) maxRight = box.right.toDouble();
      if (box.bottom > maxBottom) maxBottom = box.bottom.toDouble();
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

  File(
    targetPath,
  ).writeAsBytesSync(img.encodeJpg(_enhance(cropped), quality: 92));
}

/// The package's [ds.ScanFilter.enhance] (grayscale → contrast → normalize),
/// inlined here because it runs on an already-`copyCrop`'d [img.Image]. The
/// package only exposes filtering via a `ScanInput` (bytes/file), which would
/// force an extra encode→decode round-trip just to reuse the same three ops —
/// so the whole-image path routes through `applyFilter`, and this axis-aligned
/// crop path keeps the ops inline. Must stay in lock-step with the package.
img.Image _enhance(img.Image src) {
  var result = img.grayscale(src);
  result = img.adjustColor(result, contrast: 1.5);
  result = img.normalize(result, min: 0, max: 255);
  return result;
}

