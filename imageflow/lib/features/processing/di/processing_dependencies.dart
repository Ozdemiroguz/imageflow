import 'package:get/get.dart';

import '../../../core/platform/corner_detector.dart';
import '../../../core/services/file_service.dart';
import '../../../core/services/native_corner_detection_service.dart';
import '../data/repositories/processing_repository_impl.dart';
import '../data/services/content_detection_service.dart';
import '../data/services/document_crop_service.dart';
import '../domain/repositories/processing_repository.dart';
import '../domain/services/content_detector.dart';
import '../domain/services/document_cropper.dart';

/// Registers Processing feature infrastructure + repository dependencies.
///
/// Every collaborator is bound to its abstraction (interface → impl) so the
/// repository can be unit-tested with mocked detectors/croppers.
void registerProcessingDependencies() {
  if (!Get.isRegistered<ContentDetector>()) {
    Get.lazyPut<ContentDetector>(ContentDetectionService.new);
  }
  if (!Get.isRegistered<CornerDetector>()) {
    Get.lazyPut<CornerDetector>(NativeCornerDetectionService.new);
  }
  if (!Get.isRegistered<DocumentCropper>()) {
    Get.lazyPut<DocumentCropper>(
      () => DocumentCropService(cornerDetection: Get.find<CornerDetector>()),
    );
  }

  if (Get.isRegistered<ProcessingRepository>()) return;
  Get.lazyPut<ProcessingRepository>(
    () => ProcessingRepositoryImpl(
      fileService: Get.find<FileService>(),
      contentDetector: Get.find<ContentDetector>(),
      documentCropper: Get.find<DocumentCropper>(),
    ),
  );
}
