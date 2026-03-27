import 'package:get/get.dart';

import '../../../../core/services/modal_service.dart';
import '../actions/open_capture_dialog_action.dart';
import '../controllers/capture_controller.dart';

class CaptureBinding implements Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<CaptureController>()) {
      Get.lazyPut<CaptureController>(
        () => CaptureController(
          permissionService: Get.find(),
          modalService: Get.find(),
        ),
        fenix: true,
      );
    }

    if (!Get.isRegistered<OpenCaptureDialogAction>()) {
      Get.lazyPut<OpenCaptureDialogAction>(
        () => OpenCaptureDialogAction(modalService: Get.find<ModalService>()),
        fenix: true,
      );
    }
  }
}
