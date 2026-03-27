import '../../../../core/enums/processing_type.dart';
import '../../../../core/error/result.dart';
import '../entities/processing_result.dart';
import '../repositories/processing_repository.dart';

class ProcessImage {
  const ProcessImage(this._repository);
  final ProcessingRepository _repository;

  Future<Result<ProcessingResult>> call({
    required String imagePath,
    ProcessingType? preferredType,
    ProgressCallback? onProgress,
    bool? capturedWithFrontCamera,
  }) {
    return _repository.processImage(
      imagePath: imagePath,
      preferredType: preferredType,
      onProgress: onProgress,
      capturedWithFrontCamera: capturedWithFrontCamera,
    );
  }
}
