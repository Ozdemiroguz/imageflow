import 'package:get/get.dart';

import '../../../../core/services/camera_session_service.dart';
import '../../../../core/services/native_corner_detection_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../services/realtime_face_detection_service.dart';
import '../../services/realtime_ocr_gate_service.dart';
import '../../services/realtime_preview_builder.dart';
import '../controllers/realtime_camera_controller.dart';
import '../models/capture_realtime_config.dart';

class RealtimeBinding implements Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<CameraSessionService>()) {
      Get.lazyPut<CameraSessionService>(CameraSessionService.new);
    }
    Get.lazyPut<NativeCornerDetectionService>(NativeCornerDetectionService.new);
    Get.lazyPut<RealtimePreviewBuilder>(RealtimePreviewBuilder.new);

    Get.lazyPut<RealtimeCameraController>(
      () => RealtimeCameraController(
        permissionService: Get.find<PermissionService>(),
        cameraSessionService: Get.find<CameraSessionService>(),
        cornerDetectionService: Get.find<NativeCornerDetectionService>(),
        faceDetectionService: RealtimeFaceDetectionService(),
        ocrGateService: RealtimeOcrGateService(),
        previewBuilder: Get.find<RealtimePreviewBuilder>(),
        config: GetPlatform.isIOS
            ? CaptureRealtimeConfig.ios
            : CaptureRealtimeConfig.android,
      ),
    );
  }
}
