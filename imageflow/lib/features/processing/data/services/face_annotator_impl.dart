import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

import '../../../../core/models/face_geometry.dart';
import '../../../../core/utils/face_mask_utils.dart';
import '../../domain/services/face_annotator.dart';

/// [FaceAnnotator] backed by the `image` package, running the pixel work in a
/// background isolate.
class FaceAnnotatorImpl implements FaceAnnotator {
  const FaceAnnotatorImpl();

  @override
  Future<void> annotate({
    required String sourcePath,
    required String targetPath,
    required List<FaceRect> rects,
    required List<List<ContourPoint>> contours,
  }) async {
    await Isolate.run(() {
      final bytes = File(sourcePath).readAsBytesSync();
      final image = img.decodeImage(bytes);
      if (image == null) return;

      for (var i = 0; i < rects.length; i++) {
        final rect = rects[i];
        final contour = contours[i];
        final borderColor = img.ColorRgba8(0, 230, 118, 200);

        var faceLeft = rect.left;
        var faceTop = rect.top;
        var faceRight = rect.left + rect.width;
        var faceBottom = rect.top + rect.height;
        if (contour.isNotEmpty) {
          var contourMinX = contour.first.x;
          var contourMinY = contour.first.y;
          var contourMaxX = contour.first.x;
          var contourMaxY = contour.first.y;
          for (final p in contour) {
            if (p.x < contourMinX) contourMinX = p.x;
            if (p.y < contourMinY) contourMinY = p.y;
            if (p.x > contourMaxX) contourMaxX = p.x;
            if (p.y > contourMaxY) contourMaxY = p.y;
          }
          faceLeft = math.min(faceLeft, contourMinX);
          faceTop = math.min(faceTop, contourMinY);
          faceRight = math.max(faceRight, contourMaxX + 1);
          faceBottom = math.max(faceBottom, contourMaxY + 1);
        }

        // Clamp to image bounds
        final x = faceLeft.clamp(0, image.width - 1);
        final y = faceTop.clamp(0, image.height - 1);
        final w = (faceRight - x).clamp(1, image.width - x);
        final h = (faceBottom - y).clamp(1, image.height - y);

        // Crop → grayscale
        final cropped = img.copyCrop(image, x: x, y: y, width: w, height: h);
        final gray = img.grayscale(cropped);

        if (contour.isNotEmpty) {
          // Use real face contour polygon as mask.
          FaceMaskUtils.applyContourGrayMaskInPlace(
            image: image,
            grayCrop: gray,
            cropLeft: x,
            cropTop: y,
            cropWidth: w,
            cropHeight: h,
            contour: contour,
          );

          // Draw contour border
          for (var j = 0; j < contour.length; j++) {
            final p1 = contour[j];
            final p2 = contour[(j + 1) % contour.length];
            img.drawLine(
              image,
              x1: p1.x,
              y1: p1.y,
              x2: p2.x,
              y2: p2.y,
              color: borderColor,
              thickness: 3,
            );
          }
        } else {
          // Fallback: oval mask from bounding box
          final ovalMasked = FaceMaskUtils.buildOvalMaskedGrayImage(cropped);
          for (var py = 0; py < h; py++) {
            for (var px = 0; px < w; px++) {
              final pixel = ovalMasked.getPixel(px, py);
              if (pixel.a > 0) {
                image.setPixel(x + px, y + py, pixel);
              }
            }
          }

          // Keep border style close to contour by drawing an oval polyline.
          final cx = w / 2;
          final cy = h / 2;
          final centerX = x + cx;
          final centerY = y + cy;
          final radiusX = w / 2;
          final radiusY = h / 2;
          const segments = 64;
          for (var s = 0; s < segments; s++) {
            final t1 = (2 * math.pi * s) / segments;
            final t2 = (2 * math.pi * (s + 1)) / segments;
            final p1x = (centerX + radiusX * math.cos(t1)).round();
            final p1y = (centerY + radiusY * math.sin(t1)).round();
            final p2x = (centerX + radiusX * math.cos(t2)).round();
            final p2y = (centerY + radiusY * math.sin(t2)).round();

            img.drawLine(
              image,
              x1: p1x,
              y1: p1y,
              x2: p2x,
              y2: p2y,
              color: borderColor,
              thickness: 3,
            );
          }
        }
      }

      File(targetPath).writeAsBytesSync(img.encodeJpg(image, quality: 90));
    });
  }
}
