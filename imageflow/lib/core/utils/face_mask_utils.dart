import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

class FaceMaskUtils {
  FaceMaskUtils._();

  static Uint8List? buildContourMaskedGrayPng({
    required img.Image crop,
    required List<img.Point> contour,
  }) {
    if (contour.length < 3) return null;

    var minX = crop.width - 1;
    var minY = crop.height - 1;
    var maxX = 0;
    var maxY = 0;

    for (final p in contour) {
      final x = p.x.round().clamp(0, crop.width - 1);
      final y = p.y.round().clamp(0, crop.height - 1);
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }

    final width = (maxX - minX + 1).clamp(1, crop.width);
    final height = (maxY - minY + 1).clamp(1, crop.height);
    if (width <= 1 || height <= 1) return null;

    final sub = img.copyCrop(
      crop,
      x: minX,
      y: minY,
      width: width,
      height: height,
    );
    final shiftedContour = contour
        .map(
          (p) => img.Point(
            (p.x - minX).clamp(0.0, sub.width - 1.0),
            (p.y - minY).clamp(0.0, sub.height - 1.0),
          ),
        )
        .toList(growable: false);
    final maskContour = _convexHull(shiftedContour);
    if (maskContour.length < 3) return null;

    final gray = img.grayscale(sub.clone());
    final mask = img.Image(width: sub.width, height: sub.height);
    img.fill(mask, color: img.ColorRgba8(0, 0, 0, 255));
    img.fillPolygon(
      mask,
      vertices: maskContour,
      color: img.ColorRgba8(255, 255, 255, 255),
    );

    final output = img.Image(
      width: sub.width,
      height: sub.height,
      numChannels: 4,
    );
    img.fill(output, color: img.ColorRgba8(0, 0, 0, 0));

    for (var y = 0; y < sub.height; y++) {
      for (var x = 0; x < sub.width; x++) {
        if (mask.getPixel(x, y).r > 0) {
          final pixel = gray.getPixel(x, y);
          output.setPixelRgba(x, y, pixel.r, pixel.g, pixel.b, 255);
        }
      }
    }

    return Uint8List.fromList(img.encodePng(output));
  }

  static img.Image buildOvalMaskedGrayImage(img.Image crop) {
    final gray = img.grayscale(crop.clone());
    final output = img.Image(
      width: crop.width,
      height: crop.height,
      numChannels: 4,
    );
    img.fill(output, color: img.ColorRgba8(0, 0, 0, 0));

    final cx = (crop.width - 1) / 2.0;
    final cy = (crop.height - 1) / 2.0;
    final rx = math.max(1.0, crop.width / 2.0);
    final ry = math.max(1.0, crop.height / 2.0);

    for (var y = 0; y < crop.height; y++) {
      for (var x = 0; x < crop.width; x++) {
        final dx = (x - cx) / rx;
        final dy = (y - cy) / ry;
        if ((dx * dx + dy * dy) <= 1.0) {
          final pixel = gray.getPixel(x, y);
          output.setPixelRgba(x, y, pixel.r, pixel.g, pixel.b, 255);
        }
      }
    }

    return output;
  }

  static void applyContourGrayMaskInPlace({
    required img.Image image,
    required img.Image grayCrop,
    required int cropLeft,
    required int cropTop,
    required int cropWidth,
    required int cropHeight,
    required List<({int x, int y})> contour,
  }) {
    if (contour.length < 3) return;
    if (cropWidth <= 0 || cropHeight <= 0) return;

    final localContour = contour
        .map(
          (p) => img.Point(
            (p.x - cropLeft).clamp(0, cropWidth - 1).toDouble(),
            (p.y - cropTop).clamp(0, cropHeight - 1).toDouble(),
          ),
        )
        .toList(growable: false);
    final maskContour = _convexHull(localContour);
    if (maskContour.length < 3) return;

    final mask = img.Image(width: cropWidth, height: cropHeight);
    img.fill(mask, color: img.ColorRgba8(0, 0, 0, 255));
    img.fillPolygon(
      mask,
      vertices: maskContour,
      color: img.ColorRgba8(255, 255, 255, 255),
    );

    var minX = cropWidth - 1;
    var minY = cropHeight - 1;
    var maxX = 0;
    var maxY = 0;
    for (final p in maskContour) {
      final x = p.x.round().clamp(0, cropWidth - 1);
      final y = p.y.round().clamp(0, cropHeight - 1);
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
    if (minX > maxX || minY > maxY) return;

    for (var py = minY; py <= maxY; py++) {
      for (var px = minX; px <= maxX; px++) {
        if (mask.getPixel(px, py).r > 0) {
          image.setPixel(
            cropLeft + px,
            cropTop + py,
            grayCrop.getPixel(px, py),
          );
        }
      }
    }
  }

  static List<img.Point> _convexHull(List<img.Point> points) {
    if (points.length < 4) {
      return _dedupePoints(points);
    }

    final sorted = _dedupePoints(points)
      ..sort((a, b) {
        final dx = a.x.compareTo(b.x);
        if (dx != 0) return dx;
        return a.y.compareTo(b.y);
      });
    if (sorted.length < 4) return sorted;

    final lower = <img.Point>[];
    for (final p in sorted) {
      while (lower.length >= 2 &&
          _cross(lower[lower.length - 2], lower.last, p) <= 0) {
        lower.removeLast();
      }
      lower.add(p);
    }

    final upper = <img.Point>[];
    for (var i = sorted.length - 1; i >= 0; i--) {
      final p = sorted[i];
      while (upper.length >= 2 &&
          _cross(upper[upper.length - 2], upper.last, p) <= 0) {
        upper.removeLast();
      }
      upper.add(p);
    }

    lower.removeLast();
    upper.removeLast();
    return [...lower, ...upper];
  }

  static List<img.Point> _dedupePoints(List<img.Point> points) {
    final seen = <String>{};
    final out = <img.Point>[];
    for (final p in points) {
      final key = '${p.x.toStringAsFixed(3)}:${p.y.toStringAsFixed(3)}';
      if (!seen.add(key)) continue;
      out.add(p);
    }
    return out;
  }

  static double _cross(img.Point o, img.Point a, img.Point b) {
    final value = (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);
    return value.toDouble();
  }
}
