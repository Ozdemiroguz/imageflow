import 'dart:async';

import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/modal_service.dart';
import '../../../../core/services/permission_service.dart';

class CaptureController extends GetxController {
  CaptureController({
    required PermissionService permissionService,
    required ModalService modalService,
    ImagePicker? picker,
  }) : _permissionService = permissionService,
       _modalService = modalService,
       _picker = picker ?? ImagePicker();

  final ImagePicker _picker;
  final PermissionService _permissionService;
  final ModalService _modalService;
  static const _sourceTransitionDelay = Duration(milliseconds: 140);
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
    final image = await _runOpeningOverlay<XFile?>(
      message: _genericLoadingMessage,
      action: () =>
          _picker.pickImage(source: ImageSource.gallery, imageQuality: 90),
    );
    if (image != null) {
      await _navigateToProcessing(image.path);
    }
  }

  Future<void> pickBatchFromGallery() async {
    _closeSourceDialogIfOpen();
    await _waitForSourceTransition();
    final images = await _runOpeningOverlay<List<XFile>>(
      message: _genericLoadingMessage,
      action: () => _picker.pickMultiImage(imageQuality: 90),
    );
    if (images.isEmpty) return;

    await Get.toNamed(
      AppRoutes.batch,
      arguments: images.map((image) => image.path).toList(growable: false),
    );
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
