import 'package:get/get.dart';

import '../../../../core/platform/corner_detector.dart';
import '../../../../core/platform/object_detector.dart';
import '../../../../core/services/camera_session_service.dart';
import '../../../../core/services/document_scan_corner_detector.dart';
import '../../../../core/services/native_object_detection_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../data/datasources/realtime_face_detection_service.dart';
import '../../data/services/realtime_preview_builder.dart';
import '../controllers/realtime_camera_controller.dart';
import '../models/capture_realtime_config.dart';

class RealtimeBinding implements Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<CameraSessionService>()) {
      Get.lazyPut<CameraSessionService>(CameraSessionService.new);
    }
    // Dogfood: corner detection runs through our own document_scan package.
    Get.lazyPut<CornerDetector>(DocumentScanCornerDetector.new);
    Get.lazyPut<ObjectDetector>(NativeObjectDetectionService.new);
    Get.lazyPut<RealtimePreviewBuilder>(RealtimePreviewBuilder.new);

    Get.lazyPut<RealtimeCameraController>(
      () => RealtimeCameraController(
        permissionService: Get.find<PermissionService>(),
        cameraSessionService: Get.find<CameraSessionService>(),
        cornerDetectionService: Get.find<CornerDetector>(),
        objectDetectionService: Get.find<ObjectDetector>(),
        faceDetectionService: RealtimeFaceDetectionService(),
        previewBuilder: Get.find<RealtimePreviewBuilder>(),
        config: GetPlatform.isIOS
            ? CaptureRealtimeConfig.ios
            : CaptureRealtimeConfig.android,
      ),
    );
  }
}
