import 'dart:async';

import 'package:get/get.dart';

import '../../../../core/platform/image_picker_gateway.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/modal_service.dart';
import '../../../../core/services/permission_service.dart';

/// Drives the "add image" entry dialog: picks the source (camera, gallery,
/// or batch), gates the camera path on permission, and routes to the matching
/// screen. Holds only the dialog's transient `cameraDenied` warning — the live
/// camera session state lives in [CameraCaptureController].
class CaptureController extends GetxController {
  CaptureController({
    required PermissionService permissionService,
    required ModalService modalService,
    required ImagePickerGateway imagePicker,
  }) : _permissionService = permissionService,
       _modalService = modalService,
       _imagePicker = imagePicker;

  final ImagePickerGateway _imagePicker;
  final PermissionService _permissionService;
  final ModalService _modalService;
  // Let the capture dialog's dismiss animation finish before opening the
  // camera/gallery, so the two transitions don't visually collide.
  static const _sourceTransitionDelay = Duration(milliseconds: 140);
  // Keep the loading overlay on screen at least this long so a fast pick
  // doesn't flash it for a single frame.
  static const _navigationOverlayMinVisible = Duration(milliseconds: 180);
  static const _genericLoadingMessage = 'Loading...';

  final cameraDenied = false.obs;

  void clearCameraDeniedWarning() {
    cameraDenied.value = false;
  }

  Future<void> pickFromCamera() async {
    final granted = await _permissionService.requestCamera();
    if (!granted) {
      cameraDenied.value = true;
      return;
    }
    cameraDenied.value = false;
    _closeSourceDialogIfOpen();
    await _waitForSourceTransition();
    await _runOpeningOverlay<void>(
      message: _genericLoadingMessage,
      action: () async {
        unawaited(Get.toNamed(AppRoutes.capture));
        await _waitForOverlaySettle();
      },
    );
  }

  Future<void> pickFromGallery() async {
    _closeSourceDialogIfOpen();
    await _waitForSourceTransition();
    final imagePath = await _runOpeningOverlay<String?>(
      message: _genericLoadingMessage,
      action: _imagePicker.pickImageFromGallery,
    );
    if (imagePath != null) {
      await _navigateToProcessing(imagePath);
    }
  }

  Future<void> pickBatchFromGallery() async {
    _closeSourceDialogIfOpen();
    await _waitForSourceTransition();
    final imagePaths = await _runOpeningOverlay<List<String>>(
      message: _genericLoadingMessage,
      action: _imagePicker.pickMultipleFromGallery,
    );
    if (imagePaths.isEmpty) return;

    await Get.toNamed(AppRoutes.batch, arguments: imagePaths);
  }

  Future<void> _navigateToProcessing(String imagePath) async {
    await Get.toNamed(AppRoutes.processing, arguments: imagePath);
  }

  void _closeSourceDialogIfOpen() {
    if (Get.isDialogOpen ?? false) {
      Get.back<void>();
    }
  }

  Future<void> _waitForSourceTransition() async {
    if (Get.testMode) return;
    await Future<void>.delayed(_sourceTransitionDelay);
  }

  Future<T> _runOpeningOverlay<T>({
    required String message,
    required Future<T> Function() action,
  }) async {
    _modalService.showLoadingOverlay(message: message);
    try {
      return await action();
    } finally {
      _modalService.hideLoadingOverlay();
    }
  }

  Future<void> _waitForOverlaySettle() async {
    if (Get.testMode) return;
    await Future<void>.delayed(_navigationOverlayMinVisible);
  }
}
