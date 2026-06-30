import '../../../../core/enums/processing_type.dart';
import '../../../../core/error/result.dart';
import '../entities/processing_result.dart';
import '../services/image_processing_service.dart';

class ProcessImage {
  const ProcessImage(this._service);
  final ImageProcessingService _service;

  Future<Result<ProcessingResult>> call({
    required String imagePath,
    ProcessingType? preferredType,
    ProgressCallback? onProgress,
    bool? capturedWithFrontCamera,
  }) {
    return _service.processImage(
      imagePath: imagePath,
      preferredType: preferredType,
      onProgress: onProgress,
      capturedWithFrontCamera: capturedWithFrontCamera,
    );
  }
}
