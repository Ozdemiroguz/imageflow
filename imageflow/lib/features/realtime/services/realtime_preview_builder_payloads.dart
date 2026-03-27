part of 'realtime_preview_builder.dart';

Uint8List? _buildFacePreviewFromFrameOnIsolate(
  FacePreviewFromFramePayload payload,
) {
  final prepared = _prepareFrameImageOnIsolate(
    payload.frame,
    frameRotationDegrees: payload.frameRotationDegrees,
    mirror: payload.needsMirrorCompensation,
  );
  if (prepared == null) return null;

  final cropRect = Rect.fromLTRB(
    (payload.normalizedLeft - 0.08).clamp(0.0, 1.0),
    (payload.normalizedTop - 0.08).clamp(0.0, 1.0),
    (payload.normalizedRight + 0.08).clamp(0.0, 1.0),
    (payload.normalizedBottom + 0.08).clamp(0.0, 1.0),
  );

  final left = _clampIntIsolate(
    (cropRect.left * prepared.width).round(),
    0,
    prepared.width - 1,
  );
  final top = _clampIntIsolate(
    (cropRect.top * prepared.height).round(),
    0,
    prepared.height - 1,
  );
  final right = _clampIntIsolate(
    (cropRect.right * prepared.width).round(),
    left + 1,
    prepared.width,
  );
  final bottom = _clampIntIsolate(
    (cropRect.bottom * prepared.height).round(),
    top + 1,
    prepared.height,
  );

  final width = right - left;
  final height = bottom - top;
  if (width <= 0 || height <= 0) return null;

  final faceCrop = img.copyCrop(
    prepared,
    x: left,
    y: top,
    width: width,
    height: height,
  );

  final localContour = <img.Point>[];
  for (var i = 0; i + 1 < payload.contourPairs.length; i += 2) {
    final x = (payload.contourPairs[i] * prepared.width) - left;
    final y = (payload.contourPairs[i + 1] * prepared.height) - top;
    localContour.add(
      img.Point(
        _clampDoubleIsolate(x, 0, faceCrop.width - 1.0),
        _clampDoubleIsolate(y, 0, faceCrop.height - 1.0),
      ),
    );
  }

  final contourPairs = Float32List(localContour.length * 2);
  for (var i = 0; i < localContour.length; i++) {
    contourPairs[(i * 2)] = localContour[i].x.toDouble();
    contourPairs[(i * 2) + 1] = localContour[i].y.toDouble();
  }
  final cropPayload = FacePreviewIsolatePayload(
    width: faceCrop.width,
    height: faceCrop.height,
    rgbaBytes: TransferableTypedData.fromList([
      faceCrop.getBytes(order: img.ChannelOrder.rgba),
    ]),
    contourPairs: contourPairs,
  );
  return _buildFacePreviewOnIsolate(cropPayload);
}

Uint8List? _buildDocumentPreviewFromFrameOnIsolate(
  DocumentPreviewFromFramePayload payload,
) {
  final prepared = _prepareFrameImageOnIsolate(
    payload.frame,
    frameRotationDegrees: payload.frameRotationDegrees,
    mirror: payload.needsMirrorCompensation,
  );
  if (prepared == null) return null;

  final tl = Offset(
    (payload.topLeftX * prepared.width).clamp(0.0, prepared.width - 1.0),
    (payload.topLeftY * prepared.height).clamp(0.0, prepared.height - 1.0),
  );
  final tr = Offset(
    (payload.topRightX * prepared.width).clamp(0.0, prepared.width - 1.0),
    (payload.topRightY * prepared.height).clamp(0.0, prepared.height - 1.0),
  );
  final br = Offset(
    (payload.bottomRightX * prepared.width).clamp(0.0, prepared.width - 1.0),
    (payload.bottomRightY * prepared.height).clamp(0.0, prepared.height - 1.0),
  );
  final bl = Offset(
    (payload.bottomLeftX * prepared.width).clamp(0.0, prepared.width - 1.0),
    (payload.bottomLeftY * prepared.height).clamp(0.0, prepared.height - 1.0),
  );

  final widthTop = _distanceIsolate(tl, tr);
  final widthBottom = _distanceIsolate(bl, br);
  final heightLeft = _distanceIsolate(tl, bl);
  final heightRight = _distanceIsolate(tr, br);

  var dstWidth = ((widthTop + widthBottom) / 2).round();
  var dstHeight = ((heightLeft + heightRight) / 2).round();
  final previewScale = _computeLongSideScaleIsolate(
    width: dstWidth,
    height: dstHeight,
    maxLongSide: RealtimePreviewBuilder._maxDocumentPreviewLongSide,
  );
  if (previewScale < 1.0) {
    dstWidth = _clampIntIsolate((dstWidth * previewScale).round(), 1, dstWidth);
    dstHeight = _clampIntIsolate(
      (dstHeight * previewScale).round(),
      1,
      dstHeight,
    );
  }
  dstWidth = _clampIntIsolate(dstWidth, 1, 4096);
  dstHeight = _clampIntIsolate(dstHeight, 1, 4096);

  final docPayload = DocumentPreviewIsolatePayload(
    width: prepared.width,
    height: prepared.height,
    rgbaBytes: TransferableTypedData.fromList([
      prepared.getBytes(order: img.ChannelOrder.rgba),
    ]),
    topLeftX: tl.dx,
    topLeftY: tl.dy,
    topRightX: tr.dx,
    topRightY: tr.dy,
    bottomRightX: br.dx,
    bottomRightY: br.dy,
    bottomLeftX: bl.dx,
    bottomLeftY: bl.dy,
    dstWidth: dstWidth,
    dstHeight: dstHeight,
    isFrontCamera: payload.isFrontCamera,
  );
  return _buildDocumentPreviewOnIsolate(docPayload);
}

img.Image? _prepareFrameImageOnIsolate(
  RealtimeFramePayload payload, {
  required int frameRotationDegrees,
  required bool mirror,
}) {
  final source = _framePayloadToImageOnIsolate(payload);
  if (source == null) return null;

  var prepared = _frameToUprightImageOnIsolate(source, frameRotationDegrees);
  prepared = _downscaleForPreviewIsolate(prepared);
  if (mirror) {
    prepared = img.flipHorizontal(img.Image.from(prepared));
  }
  return prepared;
}

img.Image? _framePayloadToImageOnIsolate(RealtimeFramePayload payload) {
  final bytes = payload.primaryBytes.materialize().asUint8List();
  if (payload.isBgra8888) {
    return img.Image.fromBytes(
      width: payload.width,
      height: payload.height,
      bytes: bytes.buffer,
      bytesOffset: bytes.offsetInBytes,
      rowStride: payload.primaryRowStride,
      numChannels: 4,
      order: img.ChannelOrder.bgra,
    );
  }

  final sourceWidth = payload.width;
  final sourceHeight = payload.height;
  final sourceLongSide = math.max(sourceWidth, sourceHeight);
  final needsDownscale =
      sourceLongSide > RealtimePreviewBuilder._maxPreviewLongSide;
  final scale = needsDownscale
      ? RealtimePreviewBuilder._maxPreviewLongSide / sourceLongSide
      : 1.0;
  final targetWidth = _clampIntIsolate(
    (sourceWidth * scale).round(),
    1,
    sourceWidth,
  );
  final targetHeight = _clampIntIsolate(
    (sourceHeight * scale).round(),
    1,
    sourceHeight,
  );

  final xMap = List<int>.generate(targetWidth, (x) {
    return _clampIntIsolate(
      (x * sourceWidth) ~/ targetWidth,
      0,
      sourceWidth - 1,
    );
  }, growable: false);
  final yMap = List<int>.generate(targetHeight, (y) {
    return _clampIntIsolate(
      (y * sourceHeight) ~/ targetHeight,
      0,
      sourceHeight - 1,
    );
  }, growable: false);

  final image = img.Image(width: targetWidth, height: targetHeight);
  for (var y = 0; y < targetHeight; y++) {
    final rowOffset = yMap[y] * payload.primaryRowStride;
    for (var x = 0; x < targetWidth; x++) {
      final idx = rowOffset + xMap[x];
      if (idx >= bytes.length) continue;
      final luma = bytes[idx];
      image.setPixelRgba(x, y, luma, luma, luma, 255);
    }
  }
  return image;
}

img.Image _frameToUprightImageOnIsolate(img.Image source, int rotationDegrees) {
  return switch (rotationDegrees % 360) {
    90 => img.copyRotate(source, angle: 90),
    180 => img.copyRotate(source, angle: 180),
    270 => img.copyRotate(source, angle: 270),
    _ => source,
  };
}

img.Image _downscaleForPreviewIsolate(img.Image source) {
  final longSide = math.max(source.width, source.height);
  if (longSide <= RealtimePreviewBuilder._maxPreviewLongSide) return source;

  final scale = RealtimePreviewBuilder._maxPreviewLongSide / longSide;
  final width = _clampIntIsolate(
    (source.width * scale).round(),
    1,
    source.width,
  );
  final height = _clampIntIsolate(
    (source.height * scale).round(),
    1,
    source.height,
  );
  return img.copyResize(
    source,
    width: width,
    height: height,
    interpolation: img.Interpolation.linear,
  );
}

double _distanceIsolate(Offset a, Offset b) {
  final dx = a.dx - b.dx;
  final dy = a.dy - b.dy;
  return math.sqrt(dx * dx + dy * dy);
}

double _computeLongSideScaleIsolate({
  required int width,
  required int height,
  required int maxLongSide,
}) {
  final longSide = math.max(width, height);
  if (longSide <= maxLongSide) return 1.0;
  return maxLongSide / longSide;
}

Uint8List? _buildFacePreviewOnIsolate(FacePreviewIsolatePayload payload) {
  final bytes = payload.rgbaBytes.materialize().asUint8List();
  final crop = img.Image.fromBytes(
    width: payload.width,
    height: payload.height,
    bytes: bytes.buffer,
    bytesOffset: bytes.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );

  final contour = <img.Point>[];
  for (var i = 0; i + 1 < payload.contourPairs.length; i += 2) {
    contour.add(
      img.Point(payload.contourPairs[i], payload.contourPairs[i + 1]),
    );
  }

  if (contour.length >= 3) {
    final downscaled = _downscaleForFacePreviewIsolate(
      source: crop,
      contour: contour,
    );
    final masked = FaceMaskUtils.buildContourMaskedGrayPng(
      crop: downscaled.image,
      contour: downscaled.contour,
    );
    if (masked != null) {
      return masked;
    }
  }

  final fallback = _downscaleForFacePreviewIsolate(source: crop).image;
  final maskedFallback = FaceMaskUtils.buildOvalMaskedGrayImage(fallback);
  return Uint8List.fromList(img.encodePng(maskedFallback));
}

Uint8List _buildDocumentPreviewOnIsolate(
  DocumentPreviewIsolatePayload payload,
) {
  final bytes = payload.rgbaBytes.materialize().asUint8List();
  final source = img.Image.fromBytes(
    width: payload.width,
    height: payload.height,
    bytes: bytes.buffer,
    bytesOffset: bytes.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );

  final rectified = img.copyRectify(
    source,
    topLeft: img.Point(payload.topLeftX, payload.topLeftY),
    topRight: img.Point(payload.topRightX, payload.topRightY),
    bottomLeft: img.Point(payload.bottomLeftX, payload.bottomLeftY),
    bottomRight: img.Point(payload.bottomRightX, payload.bottomRightY),
    interpolation: img.Interpolation.linear,
    toImage: img.Image(width: payload.dstWidth, height: payload.dstHeight),
  );

  var filtered = img.normalize(
    img.adjustColor(img.grayscale(rectified), contrast: 1.45),
    min: 0,
    max: 255,
  );

  if (payload.isFrontCamera) {
    filtered = img.flipHorizontal(img.Image.from(filtered));
  }

  return Uint8List.fromList(img.encodeJpg(filtered, quality: 80));
}

({img.Image image, List<img.Point> contour}) _downscaleForFacePreviewIsolate({
  required img.Image source,
  List<img.Point>? contour,
}) {
  final longSide = math.max(source.width, source.height);
  if (longSide <= RealtimePreviewBuilder._maxFacePreviewLongSide) {
    return (image: source, contour: contour ?? const <img.Point>[]);
  }

  final scale = RealtimePreviewBuilder._maxFacePreviewLongSide / longSide;
  final width = _clampIntIsolate(
    (source.width * scale).round(),
    1,
    source.width,
  );
  final height = _clampIntIsolate(
    (source.height * scale).round(),
    1,
    source.height,
  );
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
        final dx = _clampDoubleIsolate(p.x.toDouble() * scale, 0, width - 1.0);
        final dy = _clampDoubleIsolate(p.y.toDouble() * scale, 0, height - 1.0);
        return img.Point(dx, dy);
      })
      .toList(growable: false);
  return (image: resized, contour: scaledContour);
}

int _clampIntIsolate(int value, int min, int max) {
  return value < min ? min : (value > max ? max : value);
}

double _clampDoubleIsolate(double value, double min, double max) {
  return value < min ? min : (value > max ? max : value);
}
