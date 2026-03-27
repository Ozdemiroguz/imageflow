import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'log.dart';

part 'face_thumbnail_builder_working_image.dart';

typedef FaceRectData = ({int left, int top, int width, int height});
typedef FaceContourPoint = ({int x, int y});
typedef FaceThumbnailInputData = ({
  FaceRectData rect,
  List<FaceContourPoint> contour,
});

class FaceThumbnailBuilder {
  static const _thumbMaxWidth = 108;
  static const _thumbMaxHeight = 144;
  static const _thumbPngLevel = 2;
  static const _thumbDecodeLongSide = 1800;

  static List<Uint8List> build({
    required String imagePath,
    required List<FaceThumbnailInputData> inputs,
    required String logTag,
  }) {
    final totalWatch = Stopwatch()..start();
    try {
      final file = File(imagePath);
      if (!file.existsSync()) {
        Log.warning('Source image does not exist: $imagePath', tag: logTag);
        return const <Uint8List>[];
      }

      final readWatch = Stopwatch()..start();
      final bytes = file.readAsBytesSync();
      readWatch.stop();

      final decodeWatch = Stopwatch()..start();
      final decoded = img.decodeImage(bytes);
      decodeWatch.stop();
      if (decoded == null) {
        Log.warning('decodeImage returned null: $imagePath', tag: logTag);
        return const <Uint8List>[];
      }

      final prepareWatch = Stopwatch()..start();
      final working = _prepareWorkingImage(decoded);
      prepareWatch.stop();
      final image = working.image;

      Log.debug(
        '[breakdown] ioRead=${readWatch.elapsedMilliseconds}ms '
        'decode=${decodeWatch.elapsedMilliseconds}ms '
        'prepare=${prepareWatch.elapsedMilliseconds}ms '
        'src=${decoded.width}x${decoded.height} '
        'work=${image.width}x${image.height}',
        tag: logTag,
      );

      final thumbnails = <Uint8List>[];
      for (var i = 0; i < inputs.length; i++) {
        final input = inputs[i];
        final faceWatch = Stopwatch()..start();
        try {
          final left = (input.rect.left * working.scaleX).round();
          final top = (input.rect.top * working.scaleY).round();
          final width = (input.rect.width * working.scaleX).round();
          final height = (input.rect.height * working.scaleY).round();

          final right = left + width;
          final bottom = top + height;

          final x1 = left.clamp(0, image.width - 1).toInt();
          final y1 = top.clamp(0, image.height - 1).toInt();
          final x2 = right.clamp(x1 + 1, image.width).toInt();
          final y2 = bottom.clamp(y1 + 1, image.height).toInt();

          final cropWidth = (x2 - x1).clamp(1, image.width - x1);
          final cropHeight = (y2 - y1).clamp(1, image.height - y1);
          if (cropWidth <= 0 || cropHeight <= 0) {
            Log.debug(
              'Skipping face[$i] due to invalid crop size: '
              'w=$cropWidth h=$cropHeight rect=($left,$top,$width,$height)',
              tag: logTag,
            );
            continue;
          }

          final cropWatch = Stopwatch()..start();
          final crop = img.copyCrop(
            image,
            x: x1,
            y: y1,
            width: cropWidth,
            height: cropHeight,
          );
          cropWatch.stop();

          final maskWatch = Stopwatch()..start();
          final masked = _buildMaskedPreview(
            crop: crop,
            contour: _scaleContour(input.contour, working),
            cropLeft: x1,
            cropTop: y1,
            faceIndex: i,
            logTag: logTag,
          );
          maskWatch.stop();

          final resizeWatch = Stopwatch()..start();
          final resized = _resizeForStrip(masked);
          resizeWatch.stop();

          final encodeWatch = Stopwatch()..start();
          thumbnails.add(
            Uint8List.fromList(
              img.encodePng(
                resized,
                level: _thumbPngLevel,
                filter: img.PngFilter.none,
              ),
            ),
          );
          encodeWatch.stop();
          faceWatch.stop();
          Log.debug(
            '[face:$i] crop=${crop.width}x${crop.height} '
            'cropMs=${cropWatch.elapsedMilliseconds} '
            'maskMs=${maskWatch.elapsedMilliseconds} '
            'resizeMs=${resizeWatch.elapsedMilliseconds} '
            'encodeMs=${encodeWatch.elapsedMilliseconds} '
            'totalMs=${faceWatch.elapsedMilliseconds}',
            tag: logTag,
          );
        } catch (error, stackTrace) {
          Log.error(
            'face[$i] thumbnail build failed',
            error: error,
            stackTrace: stackTrace,
            tag: logTag,
          );
          continue;
        }
      }
      totalWatch.stop();
      Log.debug(
        'Built ${thumbnails.length}/${inputs.length} face thumbnails from $imagePath '
        'total=${totalWatch.elapsedMilliseconds}ms',
        tag: logTag,
      );
      return thumbnails;
    } catch (error, stackTrace) {
      totalWatch.stop();
      Log.error(
        'Unexpected thumbnail build failure for $imagePath',
        error: error,
        stackTrace: stackTrace,
        tag: logTag,
      );
      return const <Uint8List>[];
    }
  }

  static _ThumbnailWorkingImage _prepareWorkingImage(img.Image source) {
    final longSide = math.max(source.width, source.height);
    if (longSide <= _thumbDecodeLongSide) {
      return _ThumbnailWorkingImage(image: source, scaleX: 1.0, scaleY: 1.0);
    }

    final scale = _thumbDecodeLongSide / longSide;
    final targetWidth = (source.width * scale).round().clamp(1, source.width);
    final targetHeight = (source.height * scale).round().clamp(
      1,
      source.height,
    );
    final resized = img.copyResize(
      source,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.linear,
    );

    return _ThumbnailWorkingImage(
      image: resized,
      scaleX: targetWidth / source.width,
      scaleY: targetHeight / source.height,
    );
  }

  static List<FaceContourPoint> _scaleContour(
    List<FaceContourPoint> contour,
    _ThumbnailWorkingImage working,
  ) {
    if (contour.isEmpty || (working.scaleX == 1.0 && working.scaleY == 1.0)) {
      return contour;
    }

    return contour
        .map(
          (point) => (
            x: (point.x * working.scaleX).round(),
            y: (point.y * working.scaleY).round(),
          ),
        )
        .toList(growable: false);
  }

  static img.Image _resizeForStrip(img.Image source) {
    if (source.width <= _thumbMaxWidth && source.height <= _thumbMaxHeight) {
      return source;
    }

    final ratioW = _thumbMaxWidth / source.width;
    final ratioH = _thumbMaxHeight / source.height;
    final scale = ratioW < ratioH ? ratioW : ratioH;
    if (scale >= 1.0) return source;

    final width = (source.width * scale).round().clamp(1, _thumbMaxWidth);
    final height = (source.height * scale).round().clamp(1, _thumbMaxHeight);

    return img.copyResize(
      source,
      width: width,
      height: height,
      interpolation: img.Interpolation.average,
    );
  }

  static img.Image _buildMaskedPreview({
    required img.Image crop,
    required List<FaceContourPoint> contour,
    required int cropLeft,
    required int cropTop,
    required int faceIndex,
    required String logTag,
  }) {
    if (contour.length < 3) {
      return _buildOvalMaskedGrayPreview(
        crop,
        faceIndex: faceIndex,
        logTag: logTag,
      );
    }

    final watch = Stopwatch()..start();
    try {
      final result = _buildContourMaskedGrayPreview(
        crop: crop,
        contour: contour,
        cropLeft: cropLeft,
        cropTop: cropTop,
        faceIndex: faceIndex,
        logTag: logTag,
      );
      watch.stop();
      Log.debug(
        '[face:$faceIndex] maskMode=contour total=${watch.elapsedMilliseconds}ms',
        tag: logTag,
      );
      return result;
    } catch (_) {
      watch.stop();
      Log.warning(
        '[face:$faceIndex] contour mask failed after ${watch.elapsedMilliseconds}ms; falling back to oval.',
        tag: logTag,
      );
      return _buildOvalMaskedGrayPreview(
        crop,
        faceIndex: faceIndex,
        logTag: logTag,
      );
    }
  }

  static img.Image _buildContourMaskedGrayPreview({
    required img.Image crop,
    required List<FaceContourPoint> contour,
    required int cropLeft,
    required int cropTop,
    required int faceIndex,
    required String logTag,
  }) {
    final watch = Stopwatch()..start();
    final gray = img.grayscale(crop.clone());
    final output = img.Image(
      width: crop.width,
      height: crop.height,
      numChannels: 4,
    );
    img.fill(output, color: img.ColorRgba8(0, 0, 0, 0));

    final relativeContour = contour
        .map((p) => (x: p.x - cropLeft, y: p.y - cropTop))
        .toList(growable: false);
    if (relativeContour.length < 3) {
      return _buildOvalMaskedGrayPreview(
        crop,
        faceIndex: faceIndex,
        logTag: logTag,
      );
    }

    var minX = crop.width - 1;
    var minY = crop.height - 1;
    var maxX = 0;
    var maxY = 0;
    for (final point in relativeContour) {
      final x = point.x.clamp(0, crop.width - 1).toInt();
      final y = point.y.clamp(0, crop.height - 1).toInt();
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }

    if (minX > maxX || minY > maxY) {
      return _buildOvalMaskedGrayPreview(
        crop,
        faceIndex: faceIndex,
        logTag: logTag,
      );
    }

    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        if (_isPointInPolygon(x, y, relativeContour)) {
          final p = gray.getPixel(x, y);
          output.setPixelRgba(x, y, p.r, p.g, p.b, 255);
        }
      }
    }
    watch.stop();
    final boundW = (maxX - minX + 1).clamp(0, crop.width);
    final boundH = (maxY - minY + 1).clamp(0, crop.height);
    Log.debug(
      '[face:$faceIndex] contourFill bounds=${boundW}x$boundH '
      'points=${relativeContour.length} ms=${watch.elapsedMilliseconds}',
      tag: logTag,
    );

    return output;
  }

  static img.Image _buildOvalMaskedGrayPreview(
    img.Image crop, {
    required int faceIndex,
    required String logTag,
  }) {
    final watch = Stopwatch()..start();
    final gray = img.grayscale(crop.clone());
    final output = img.Image(
      width: crop.width,
      height: crop.height,
      numChannels: 4,
    );
    img.fill(output, color: img.ColorRgba8(0, 0, 0, 0));

    final cx = (crop.width - 1) / 2.0;
    final cy = (crop.height - 1) / 2.0;
    final rx = (crop.width / 2.0).clamp(1.0, double.infinity);
    final ry = (crop.height / 2.0).clamp(1.0, double.infinity);

    for (var y = 0; y < crop.height; y++) {
      for (var x = 0; x < crop.width; x++) {
        final dx = (x - cx) / rx;
        final dy = (y - cy) / ry;
        if ((dx * dx + dy * dy) <= 1.0) {
          final p = gray.getPixel(x, y);
          output.setPixelRgba(x, y, p.r, p.g, p.b, 255);
        }
      }
    }
    watch.stop();
    Log.debug(
      '[face:$faceIndex] ovalMask size=${crop.width}x${crop.height} '
      'ms=${watch.elapsedMilliseconds}',
      tag: logTag,
    );

    return output;
  }

  static bool _isPointInPolygon(int x, int y, List<FaceContourPoint> polygon) {
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].x.toDouble();
      final yi = polygon[i].y.toDouble();
      final xj = polygon[j].x.toDouble();
      final yj = polygon[j].y.toDouble();

      final intersects =
          (yi > y) != (yj > y) &&
          x < (xj - xi) * (y - yi) / ((yj - yi) + 1e-9) + xi;
      if (intersects) inside = !inside;
    }
    return inside;
  }
}

