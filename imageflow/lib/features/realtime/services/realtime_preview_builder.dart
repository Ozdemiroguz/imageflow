import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

import '../../../core/models/normalized_corners.dart';
import '../../../core/utils/face_mask_utils.dart';
import '../presentation/models/realtime_preview_payloads.dart';

part 'realtime_preview_builder_payloads.dart';

/// Realtime image-processing helper for preview bytes.
/// This is a plain class, not a GetxService.
class RealtimePreviewBuilder {
  CameraImage? _cachedFrame;
  img.Image? _cachedSourceImage;
  CameraImage? _cachedPreparedFrame;
  img.Image? _cachedPreparedBaseImage;
  img.Image? _cachedPreparedMirroredImage;
  var _cachedPreparedRotation = 0;

  int _cachedXMapSourceWidth = -1;
  int _cachedXMapTargetWidth = -1;
  List<int> _cachedXIndexMap = const [];
  int _cachedYMapSourceHeight = -1;
  int _cachedYMapTargetHeight = -1;
  List<int> _cachedYIndexMap = const [];
  var _facePreviewRequestId = 0;
  var _documentPreviewRequestId = 0;

  static const _maxPreviewLongSide = 840;
  static const _maxFacePreviewLongSide = 360;
  static const _maxDocumentPreviewLongSide = 720;

  RealtimeFramePayload? _toFramePayload(CameraImage frame) {
    if (frame.planes.isEmpty) return null;

    if (frame.planes.length == 1) {
      final plane = frame.planes.first;
      return RealtimeFramePayload(
        width: frame.width,
        height: frame.height,
        isBgra8888: true,
        primaryBytes: TransferableTypedData.fromList([plane.bytes]),
        primaryRowStride: plane.bytesPerRow,
      );
    }

    final yPlane = frame.planes.first;
    return RealtimeFramePayload(
      width: frame.width,
      height: frame.height,
      isBgra8888: false,
      primaryBytes: TransferableTypedData.fromList([yPlane.bytes]),
      primaryRowStride: yPlane.bytesPerRow,
    );
  }

  Future<Uint8List?> buildFacePreview({
    required CameraImage frame,
    required Rect normalizedFaceRect,
    required List<Offset> normalizedContour,
    required int frameRotationDegrees,
    required bool needsMirrorCompensation,
  }) async {
    final requestId = ++_facePreviewRequestId;
    final framePayload = _toFramePayload(frame);
    if (framePayload == null) return null;

    final contourPairs = Float32List(normalizedContour.length * 2);
    for (var i = 0; i < normalizedContour.length; i++) {
      contourPairs[(i * 2)] = normalizedContour[i].dx;
      contourPairs[(i * 2) + 1] = normalizedContour[i].dy;
    }
    final payload = FacePreviewFromFramePayload(
      frame: framePayload,
      normalizedLeft: normalizedFaceRect.left,
      normalizedTop: normalizedFaceRect.top,
      normalizedRight: normalizedFaceRect.right,
      normalizedBottom: normalizedFaceRect.bottom,
      contourPairs: contourPairs,
      frameRotationDegrees: frameRotationDegrees,
      needsMirrorCompensation: needsMirrorCompensation,
    );

    try {
      final preview = await Isolate.run<Uint8List?>(
        () => _buildFacePreviewFromFrameOnIsolate(payload),
      );
      if (requestId != _facePreviewRequestId) return null;
      if (preview != null) return preview;
    } catch (_) {
      // Fall back to local path if isolate cannot process this frame.
    }

    if (requestId != _facePreviewRequestId) return null;

    final image = _resolvePreparedImage(
      frame: frame,
      frameRotationDegrees: frameRotationDegrees,
      mirror: needsMirrorCompensation,
    );
    if (image == null) return null;

    final cropRect = _expandedNormalizedRect(normalizedFaceRect, padding: 0.08);
    final left = _clampInt(
      (cropRect.left * image.width).round(),
      0,
      image.width - 1,
    );
    final top = _clampInt(
      (cropRect.top * image.height).round(),
      0,
      image.height - 1,
    );
    final right = _clampInt(
      (cropRect.right * image.width).round(),
      left + 1,
      image.width,
    );
    final bottom = _clampInt(
      (cropRect.bottom * image.height).round(),
      top + 1,
      image.height,
    );
    final width = right - left;
    final height = bottom - top;
    if (width <= 0 || height <= 0) return null;

    final faceCrop = img.copyCrop(
      image,
      x: left,
      y: top,
      width: width,
      height: height,
    );
    final localContour = normalizedContour
        .map((p) {
          final x = (p.dx * image.width) - left;
          final y = (p.dy * image.height) - top;
          return img.Point(
            _clampDouble(x, 0, faceCrop.width - 1.0),
            _clampDouble(y, 0, faceCrop.height - 1.0),
          );
        })
        .toList(growable: false);

    return _buildFacePreviewFallback(
      faceCrop: faceCrop,
      localContour: localContour,
    );
  }

  Future<Uint8List?> buildDocumentPreview({
    required CameraImage frame,
    required NormalizedCorners corners,
    required bool isFrontCamera,
    required int frameRotationDegrees,
    required bool needsMirrorCompensation,
  }) async {
    final requestId = ++_documentPreviewRequestId;
    final framePayload = _toFramePayload(frame);
    if (framePayload == null) return null;

    final payload = DocumentPreviewFromFramePayload(
      frame: framePayload,
      topLeftX: corners.topLeft.x,
      topLeftY: corners.topLeft.y,
      topRightX: corners.topRight.x,
      topRightY: corners.topRight.y,
      bottomRightX: corners.bottomRight.x,
      bottomRightY: corners.bottomRight.y,
      bottomLeftX: corners.bottomLeft.x,
      bottomLeftY: corners.bottomLeft.y,
      frameRotationDegrees: frameRotationDegrees,
      needsMirrorCompensation: needsMirrorCompensation,
      isFrontCamera: isFrontCamera,
    );

    try {
      final preview = await Isolate.run<Uint8List?>(
        () => _buildDocumentPreviewFromFrameOnIsolate(payload),
      );
      if (requestId != _documentPreviewRequestId) return null;
      if (preview != null) return preview;
    } catch (_) {
      // Fall back to local path if isolate cannot process this frame.
    }

    if (requestId != _documentPreviewRequestId) return null;

    final image = _resolvePreparedImage(
      frame: frame,
      frameRotationDegrees: frameRotationDegrees,
      mirror: needsMirrorCompensation,
    );
    if (image == null) return null;

    final tl = _toPixel(corners.topLeft, image.width, image.height);
    final tr = _toPixel(corners.topRight, image.width, image.height);
    final br = _toPixel(corners.bottomRight, image.width, image.height);
    final bl = _toPixel(corners.bottomLeft, image.width, image.height);
    final widthTop = _distance(tl, tr);
    final widthBottom = _distance(bl, br);
    final heightLeft = _distance(tl, bl);
    final heightRight = _distance(tr, br);
    var dstWidth = ((widthTop + widthBottom) / 2).round();
    var dstHeight = ((heightLeft + heightRight) / 2).round();
    final previewScale = _computeLongSideScale(
      width: dstWidth,
      height: dstHeight,
      maxLongSide: _maxDocumentPreviewLongSide,
    );
    if (previewScale < 1.0) {
      dstWidth = _clampInt((dstWidth * previewScale).round(), 1, dstWidth);
      dstHeight = _clampInt((dstHeight * previewScale).round(), 1, dstHeight);
    }
    dstWidth = _clampInt(dstWidth, 1, 4096);
    dstHeight = _clampInt(dstHeight, 1, 4096);

    return _buildDocumentPreviewFallback(
      image: image,
      tl: tl,
      tr: tr,
      br: br,
      bl: bl,
      dstWidth: dstWidth,
      dstHeight: dstHeight,
      isFrontCamera: isFrontCamera,
    );
  }

  Uint8List? _buildFacePreviewFallback({
    required img.Image faceCrop,
    required List<img.Point> localContour,
  }) {
    if (localContour.length >= 3) {
      final downscaled = _downscaleForFacePreview(
        source: faceCrop,
        contour: localContour,
      );
      final masked = FaceMaskUtils.buildContourMaskedGrayPng(
        crop: downscaled.image,
        contour: downscaled.contour,
      );
      if (masked != null) {
        return masked;
      }
    }

    final fallbackCrop = _downscaleForFacePreview(source: faceCrop).image;
    final maskedFallback = FaceMaskUtils.buildOvalMaskedGrayImage(fallbackCrop);
    return Uint8List.fromList(img.encodePng(maskedFallback));
  }

  Uint8List _buildDocumentPreviewFallback({
    required img.Image image,
    required Offset tl,
    required Offset tr,
    required Offset br,
    required Offset bl,
    required int dstWidth,
    required int dstHeight,
    required bool isFrontCamera,
  }) {
    final dst = img.Image(width: dstWidth, height: dstHeight);
    final rectified = img.copyRectify(
      image,
      topLeft: img.Point(tl.dx, tl.dy),
      topRight: img.Point(tr.dx, tr.dy),
      bottomLeft: img.Point(bl.dx, bl.dy),
      bottomRight: img.Point(br.dx, br.dy),
      interpolation: img.Interpolation.linear,
      toImage: dst,
    );

    var filtered = img.normalize(
      img.adjustColor(img.grayscale(rectified), contrast: 1.45),
      min: 0,
      max: 255,
    );

    if (isFrontCamera) {
      filtered = img.flipHorizontal(img.Image.from(filtered));
    }
    return Uint8List.fromList(img.encodeJpg(filtered, quality: 80));
  }

  img.Image? _frameToImage(CameraImage frame) {
    if (frame.planes.isEmpty) return null;

    // iOS: bgra8888 single plane
    if (frame.planes.length == 1) {
      final plane = frame.planes.first;
      return img.Image.fromBytes(
        width: frame.width,
        height: frame.height,
        bytes: plane.bytes.buffer,
        bytesOffset: plane.bytes.offsetInBytes,
        rowStride: plane.bytesPerRow,
        numChannels: 4,
        order: img.ChannelOrder.bgra,
      );
    }

    // Android: build a lightweight grayscale preview from Y plane.
    final yPlane = frame.planes.first;
    final sourceWidth = frame.width;
    final sourceHeight = frame.height;
    final sourceLongSide = math.max(sourceWidth, sourceHeight);
    final needsDownscale = sourceLongSide > _maxPreviewLongSide;
    final scale = needsDownscale ? _maxPreviewLongSide / sourceLongSide : 1.0;
    final targetWidth = _clampInt(
      (sourceWidth * scale).round(),
      1,
      sourceWidth,
    );
    final targetHeight = _clampInt(
      (sourceHeight * scale).round(),
      1,
      sourceHeight,
    );
    final image = img.Image(width: targetWidth, height: targetHeight);
    final xIndexMap = _resolveXIndexMap(
      sourceWidth: sourceWidth,
      targetWidth: targetWidth,
    );
    final yIndexMap = _resolveYIndexMap(
      sourceHeight: sourceHeight,
      targetHeight: targetHeight,
    );

    for (var y = 0; y < targetHeight; y++) {
      final rowOffset = yIndexMap[y] * yPlane.bytesPerRow;
      for (var x = 0; x < targetWidth; x++) {
        final idx = rowOffset + xIndexMap[x];
        if (idx >= yPlane.bytes.length) continue;
        final luma = yPlane.bytes[idx];
        image.setPixelRgba(x, y, luma, luma, luma, 255);
      }
    }

    return image;
  }

  img.Image? _resolveSourceImage(CameraImage frame) {
    if (identical(_cachedFrame, frame)) {
      return _cachedSourceImage;
    }

    final built = _frameToImage(frame);
    _cachedFrame = frame;
    _cachedSourceImage = built;
    _cachedPreparedFrame = null;
    _cachedPreparedBaseImage = null;
    _cachedPreparedMirroredImage = null;
    return built;
  }

  img.Image? _resolvePreparedImage({
    required CameraImage frame,
    required int frameRotationDegrees,
    required bool mirror,
  }) {
    final normalizedRotation = frameRotationDegrees % 360;
    final hasCachedBase =
        identical(_cachedPreparedFrame, frame) &&
        _cachedPreparedBaseImage != null &&
        _cachedPreparedRotation == normalizedRotation;

    if (!hasCachedBase) {
      final source = _resolveSourceImage(frame);
      if (source == null) return null;

      var prepared = _frameToUprightImage(source, normalizedRotation);
      prepared = _downscaleForPreview(prepared);

      _cachedPreparedFrame = frame;
      _cachedPreparedRotation = normalizedRotation;
      _cachedPreparedBaseImage = prepared;
      _cachedPreparedMirroredImage = null;
    }

    final base = _cachedPreparedBaseImage;
    if (base == null) return null;
    if (!mirror) return base;

    final mirrored = _cachedPreparedMirroredImage;
    if (mirrored != null) return mirrored;

    final builtMirrored = img.flipHorizontal(img.Image.from(base));
    _cachedPreparedMirroredImage = builtMirrored;
    return builtMirrored;
  }

  img.Image _downscaleForPreview(img.Image source) {
    final longSide = math.max(source.width, source.height);
    if (longSide <= _maxPreviewLongSide) return source;

    final scale = _maxPreviewLongSide / longSide;
    final width = _clampInt((source.width * scale).round(), 1, source.width);
    final height = _clampInt((source.height * scale).round(), 1, source.height);
    return img.copyResize(
      source,
      width: width,
      height: height,
      interpolation: img.Interpolation.linear,
    );
  }

  ({img.Image image, List<img.Point> contour}) _downscaleForFacePreview({
    required img.Image source,
    List<img.Point>? contour,
  }) {
    final longSide = math.max(source.width, source.height);
    if (longSide <= _maxFacePreviewLongSide) {
      return (image: source, contour: contour ?? const <img.Point>[]);
    }

    final scale = _maxFacePreviewLongSide / longSide;
    final width = _clampInt((source.width * scale).round(), 1, source.width);
    final height = _clampInt((source.height * scale).round(), 1, source.height);
    final resized = img.copyResize(
      source,
      width: width,
      height: height,
      interpolation: img.Interpolation.linear,
    );

    if (contour == null || contour.isEmpty) {
      return (image: resized, contour: const <img.Point>[]);
    }

    final scaledContour = contour
        .map((p) {
          final dx = _clampDouble(p.x.toDouble() * scale, 0, width - 1.0);
          final dy = _clampDouble(p.y.toDouble() * scale, 0, height - 1.0);
          return img.Point(dx, dy);
        })
        .toList(growable: false);
    return (image: resized, contour: scaledContour);
  }

  img.Image _frameToUprightImage(img.Image source, int rotationDegrees) {
    return switch (rotationDegrees % 360) {
      90 => img.copyRotate(source, angle: 90),
      180 => img.copyRotate(source, angle: 180),
      270 => img.copyRotate(source, angle: 270),
      _ => source,
    };
  }

  Rect _expandedNormalizedRect(Rect source, {required double padding}) {
    final expanded = Rect.fromLTRB(
      source.left - padding,
      source.top - padding,
      source.right + padding,
      source.bottom + padding,
    );
    return Rect.fromLTRB(
      expanded.left.clamp(0.0, 1.0),
      expanded.top.clamp(0.0, 1.0),
      expanded.right.clamp(0.0, 1.0),
      expanded.bottom.clamp(0.0, 1.0),
    );
  }

  Offset _toPixel(({double x, double y}) point, int width, int height) {
    return Offset(
      (point.x * width).clamp(0.0, width - 1.0),
      (point.y * height).clamp(0.0, height - 1.0),
    );
  }

  double _distance(Offset a, Offset b) {
    final dx = a.dx - b.dx;
    final dy = a.dy - b.dy;
    return math.sqrt(dx * dx + dy * dy);
  }

  List<int> _resolveXIndexMap({
    required int sourceWidth,
    required int targetWidth,
  }) {
    if (_cachedXMapSourceWidth == sourceWidth &&
        _cachedXMapTargetWidth == targetWidth &&
        _cachedXIndexMap.isNotEmpty) {
      return _cachedXIndexMap;
    }

    _cachedXMapSourceWidth = sourceWidth;
    _cachedXMapTargetWidth = targetWidth;
    _cachedXIndexMap = List<int>.generate(targetWidth, (x) {
      return _clampInt((x * sourceWidth) ~/ targetWidth, 0, sourceWidth - 1);
    }, growable: false);
    return _cachedXIndexMap;
  }

  List<int> _resolveYIndexMap({
    required int sourceHeight,
    required int targetHeight,
  }) {
    if (_cachedYMapSourceHeight == sourceHeight &&
        _cachedYMapTargetHeight == targetHeight &&
        _cachedYIndexMap.isNotEmpty) {
      return _cachedYIndexMap;
    }

    _cachedYMapSourceHeight = sourceHeight;
    _cachedYMapTargetHeight = targetHeight;
    _cachedYIndexMap = List<int>.generate(targetHeight, (y) {
      return _clampInt((y * sourceHeight) ~/ targetHeight, 0, sourceHeight - 1);
    }, growable: false);
    return _cachedYIndexMap;
  }

  double _computeLongSideScale({
    required int width,
    required int height,
    required int maxLongSide,
  }) {
    final longSide = math.max(width, height);
    if (longSide <= maxLongSide) return 1.0;
    return maxLongSide / longSide;
  }

  int _clampInt(int value, int min, int max) {
    return value < min ? min : (value > max ? max : value);
  }

  double _clampDouble(double value, double min, double max) {
    return value < min ? min : (value > max ? max : value);
  }
}
