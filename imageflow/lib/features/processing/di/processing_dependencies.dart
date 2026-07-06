import 'package:get/get.dart';

import '../../../core/platform/corner_detector.dart';
import '../../../core/services/document_scan_corner_detector.dart';
import '../../../core/services/file_service.dart';
import '../data/services/content_detection_service.dart';
import '../data/services/document_crop_service.dart';
import '../data/services/face_annotator_impl.dart';
import '../data/services/image_processing_service_impl.dart';
import '../domain/services/content_detector.dart';
import '../domain/services/document_cropper.dart';
import '../domain/services/face_annotator.dart';
import '../domain/services/image_processing_service.dart';

/// Registers the Processing feature's infrastructure + service dependencies.
///
/// Every collaborator is bound to its abstraction (interface → impl) so the
/// processing service can be unit-tested with mocked detectors/croppers.
void registerProcessingDependencies() {
  if (!Get.isRegistered<ContentDetector>()) {
    Get.lazyPut<ContentDetector>(ContentDetectionService.new);
  }
  if (!Get.isRegistered<CornerDetector>()) {
    // Dogfood: corner detection runs through our own document_scan package,
    // adapted to the CornerDetector seam.
    Get.lazyPut<CornerDetector>(DocumentScanCornerDetector.new);
  }
  if (!Get.isRegistered<DocumentCropper>()) {
    // Crop + perspective correction run through the document_scan package
    // directly (detector + processor), so no CornerDetector is injected here.
    Get.lazyPut<DocumentCropper>(DocumentCropService.new);
  }
  if (!Get.isRegistered<FaceAnnotator>()) {
    Get.lazyPut<FaceAnnotator>(FaceAnnotatorImpl.new);
  }

  if (Get.isRegistered<ImageProcessingService>()) return;
  Get.lazyPut<ImageProcessingService>(
    () => ImageProcessingServiceImpl(
      fileService: Get.find<FileService>(),
      contentDetector: Get.find<ContentDetector>(),
      documentCropper: Get.find<DocumentCropper>(),
      faceAnnotator: Get.find<FaceAnnotator>(),
    ),
  );
}
