import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Per-frame geometry inputs the stream handler feeds into the detection
/// pipeline: how the current frame is rotated and mirrored.
///
/// These values are owned by the controller (they depend on live camera
/// orientation), so they are provided as callbacks rather than plain values.
/// Bundling the six rotation/mirror callbacks here keeps the stream handler's
/// constructor focused instead of threading them one by one.
class RealtimeFrameGeometrySource {
  const RealtimeFrameGeometrySource({
    required void Function() sync,
    required InputImageRotation Function() mlKitRotation,
    required int Function() nativeRotationDegrees,
    required int Function() frameImageRotationDegrees,
    required bool Function() isFrontCamera,
    required bool Function() needsMirrorCompensation,
  }) : _sync = sync,
       _mlKitRotation = mlKitRotation,
       _nativeRotationDegrees = nativeRotationDegrees,
       _frameImageRotationDegrees = frameImageRotationDegrees,
       _isFrontCamera = isFrontCamera,
       _needsMirrorCompensation = needsMirrorCompensation;

  final void Function() _sync;
  final InputImageRotation Function() _mlKitRotation;
  final int Function() _nativeRotationDegrees;
  final int Function() _frameImageRotationDegrees;
  final bool Function() _isFrontCamera;
  final bool Function() _needsMirrorCompensation;

  /// Refreshes the cached rotation from the live camera before the getters are
  /// read for the current frame. Call once per frame, before reading the rest.
  void sync() => _sync();

  InputImageRotation get mlKitRotation => _mlKitRotation();
  int get nativeRotationDegrees => _nativeRotationDegrees();
  int get frameImageRotationDegrees => _frameImageRotationDegrees();
  bool get isFrontCamera => _isFrontCamera();
  bool get needsMirrorCompensation => _needsMirrorCompensation();
}
