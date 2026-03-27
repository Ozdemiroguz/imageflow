import 'dart:isolate';
import 'dart:typed_data';

class RealtimeFramePayload {
  const RealtimeFramePayload({
    required this.width,
    required this.height,
    required this.isBgra8888,
    required this.primaryBytes,
    required this.primaryRowStride,
  });

  final int width;
  final int height;
  final bool isBgra8888;
  final TransferableTypedData primaryBytes;
  final int primaryRowStride;
}

class FacePreviewFromFramePayload {
  const FacePreviewFromFramePayload({
    required this.frame,
    required this.normalizedLeft,
    required this.normalizedTop,
    required this.normalizedRight,
    required this.normalizedBottom,
    required this.contourPairs,
    required this.frameRotationDegrees,
    required this.needsMirrorCompensation,
  });

  final RealtimeFramePayload frame;
  final double normalizedLeft;
  final double normalizedTop;
  final double normalizedRight;
  final double normalizedBottom;
  final Float32List contourPairs;
  final int frameRotationDegrees;
  final bool needsMirrorCompensation;
}

class DocumentPreviewFromFramePayload {
  const DocumentPreviewFromFramePayload({
    required this.frame,
    required this.topLeftX,
    required this.topLeftY,
    required this.topRightX,
    required this.topRightY,
    required this.bottomRightX,
    required this.bottomRightY,
    required this.bottomLeftX,
    required this.bottomLeftY,
    required this.frameRotationDegrees,
    required this.needsMirrorCompensation,
    required this.isFrontCamera,
  });

  final RealtimeFramePayload frame;
  final double topLeftX;
  final double topLeftY;
  final double topRightX;
  final double topRightY;
  final double bottomRightX;
  final double bottomRightY;
  final double bottomLeftX;
  final double bottomLeftY;
  final int frameRotationDegrees;
  final bool needsMirrorCompensation;
  final bool isFrontCamera;
}

class FacePreviewIsolatePayload {
  const FacePreviewIsolatePayload({
    required this.width,
    required this.height,
    required this.rgbaBytes,
    required this.contourPairs,
  });

  final int width;
  final int height;
  final TransferableTypedData rgbaBytes;
  final Float32List contourPairs;
}

class DocumentPreviewIsolatePayload {
  const DocumentPreviewIsolatePayload({
    required this.width,
    required this.height,
    required this.rgbaBytes,
    required this.topLeftX,
    required this.topLeftY,
    required this.topRightX,
    required this.topRightY,
    required this.bottomRightX,
    required this.bottomRightY,
    required this.bottomLeftX,
    required this.bottomLeftY,
    required this.dstWidth,
    required this.dstHeight,
    required this.isFrontCamera,
  });

  final int width;
  final int height;
  final TransferableTypedData rgbaBytes;
  final double topLeftX;
  final double topLeftY;
  final double topRightX;
  final double topRightY;
  final double bottomRightX;
  final double bottomRightY;
  final double bottomLeftX;
  final double bottomLeftY;
  final int dstWidth;
  final int dstHeight;
  final bool isFrontCamera;
}
