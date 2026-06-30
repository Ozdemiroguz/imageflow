import '../../../../core/services/modal_service.dart';
import '../controllers/capture_controller.dart';
import '../widgets/capture_dialog.dart';

class OpenCaptureDialogAction {
  OpenCaptureDialogAction({
    required ModalService modalService,
    required CaptureController captureController,
  }) : _modalService = modalService,
       _captureController = captureController;

  final ModalService _modalService;
  final CaptureController _captureController;

  Future<void> open() async {
    _captureController.clearCameraDeniedWarning();
    await _modalService.showDialogWidget<void>(
      CaptureDialog(
        onPickFromCamera: _captureController.pickFromCamera,
        onPickFromGallery: _captureController.pickFromGallery,
        onPickBatchFromGallery: _captureController.pickBatchFromGallery,
        cameraDenied: _captureController.cameraDenied,
      ),
    );
  }
}
