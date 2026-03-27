import 'package:get/get.dart';

import '../../../../core/services/camera_session_service.dart';
import '../../../../core/services/permission_service.dart';
import '../controllers/camera_capture_controller.dart';
import '../models/camera_capture_config.dart';

class CameraCaptureBinding implements Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<CameraSessionService>()) {
      Get.lazyPut<CameraSessionService>(CameraSessionService.new);
    }

    Get.lazyPut<CameraCaptureController>(
      () => CameraCaptureController(
        permissionService: Get.find<PermissionService>(),
        cameraSessionService: Get.find<CameraSessionService>(),
        config: GetPlatform.isIOS
            ? CameraCaptureConfig.ios
            : CameraCaptureConfig.android,
      ),
    );
  }
}
