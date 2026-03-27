import 'package:get/get.dart';

import '../data/services/content_detection_service.dart';
import '../data/services/document_crop_service.dart';
import '../../../core/services/file_service.dart';
import '../../../core/services/native_corner_detection_service.dart';
import '../data/repositories/processing_repository_impl.dart';
import '../domain/repositories/processing_repository.dart';

/// Registers Processing feature infrastructure + repository dependencies.
void registerProcessingDependencies() {
  if (!Get.isRegistered<ContentDetectionService>()) {
    Get.lazyPut<ContentDetectionService>(ContentDetectionService.new);
  }
  if (!Get.isRegistered<NativeCornerDetectionService>()) {
    Get.lazyPut<NativeCornerDetectionService>(NativeCornerDetectionService.new);
  }
  if (!Get.isRegistered<DocumentCropService>()) {
    Get.lazyPut<DocumentCropService>(
      () => DocumentCropService(
        cornerDetection: Get.find<NativeCornerDetectionService>(),
      ),
    );
  }

  if (Get.isRegistered<ProcessingRepository>()) return;
  Get.lazyPut<ProcessingRepository>(
    () => ProcessingRepositoryImpl(
      fileService: Get.find<FileService>(),
      contentDetectionService: Get.find<ContentDetectionService>(),
      documentCropService: Get.find<DocumentCropService>(),
    ),
  );
}
