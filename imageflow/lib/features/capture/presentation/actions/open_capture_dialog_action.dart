import 'package:get/get.dart';

import '../../../../core/services/modal_service.dart';
import '../controllers/capture_controller.dart';
import '../widgets/capture_dialog.dart';

class OpenCaptureDialogAction {
  OpenCaptureDialogAction({required ModalService modalService})
    : _modalService = modalService;

  final ModalService _modalService;

  Future<void> open() async {
    final captureController = Get.find<CaptureController>();
    captureController.clearCameraDeniedWarning();
    await _modalService.showDialogWidget<void>(
      CaptureDialog(
        onPickFromCamera: captureController.pickFromCamera,
        onPickFromGallery: captureController.pickFromGallery,
        onPickBatchFromGallery: captureController.pickBatchFromGallery,
        cameraDenied: captureController.cameraDenied,
      ),
    );
  }
}
