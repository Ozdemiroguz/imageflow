part of 'camera_capture_page.dart';

class _CameraPreview extends StatelessWidget {
  const _CameraPreview({required this.controller});

  final CameraCaptureController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.hasCameraPermission.value) {
      return const SizedBox.shrink();
    }

    final cameraController = controller.cameraController;
    if (cameraController == null) {
      return const SizedBox.shrink();
    }

    try {
      if (!cameraController.value.isInitialized ||
          cameraController.value.previewSize == null) {
        return const SizedBox.shrink();
      }
    } catch (_) {
      return const SizedBox.shrink();
    }

    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: cameraController.value.previewSize!.height,
            height: cameraController.value.previewSize!.width,
            child: Transform.flip(
              flipX: controller.isFrontCamera,
              child: CameraPreview(cameraController),
            ),
          ),
        ),
      ),
    );
  }
}

