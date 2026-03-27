import 'package:camera/camera.dart';
import 'package:get/get.dart';

import '../../../core/error/failures.dart';
import '../../../core/routes/app_routes.dart';

/// Presentation helper for camera capture actions (flash/capture).
/// This is a plain class, not a GetxService.
class CameraCaptureActionsHelper {
  CameraCaptureActionsHelper({
    required CameraController? Function() cameraController,
    required Rx<FlashMode> flashMode,
    required RxBool isCapturing,
    required Rxn<Failure> failure,
    required bool Function() isClosed,
    required bool Function() isFrontCamera,
  }) : _cameraController = cameraController,
       _flashMode = flashMode,
       _isCapturing = isCapturing,
       _failure = failure,
       _isClosed = isClosed,
       _isFrontCamera = isFrontCamera;

  final CameraController? Function() _cameraController;
  final Rx<FlashMode> _flashMode;
  final RxBool _isCapturing;
  final Rxn<Failure> _failure;
  final bool Function() _isClosed;
  final bool Function() _isFrontCamera;

  Future<void> toggleFlashMode() async {
    final cam = _cameraController();
    if (cam == null || !cam.value.isInitialized) return;

    final next = switch (_flashMode.value) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      FlashMode.always => FlashMode.off,
      FlashMode.torch => FlashMode.off,
    };

    try {
      await cam.setFlashMode(next);
      _flashMode.value = next;
    } on CameraException catch (e) {
      _failure.value = CameraFailure('Flash mode failed: ${e.description}');
    } catch (e) {
      _failure.value = CameraFailure('Flash mode failed: $e');
    }
  }

  Future<void> capture() async {
    if (_isCapturing.value) return;
    final cam = _cameraController();
    if (cam == null || !cam.value.isInitialized) return;

    _isCapturing.value = true;
    try {
      final file = await cam.takePicture();
      if (_isClosed()) return;
      await Get.offNamed(
        AppRoutes.processing,
        arguments: <String, dynamic>{
          'imagePath': file.path,
          'capturedWithFrontCamera': _isFrontCamera(),
        },
      );
    } on CameraException catch (e) {
      if (_isClosed()) return;
      _failure.value = CameraFailure('Capture failed: ${e.description}');
    } catch (e) {
      if (_isClosed()) return;
      _failure.value = CameraFailure('Capture failed: $e');
    } finally {
      if (!_isClosed()) _isCapturing.value = false;
    }
  }
}
