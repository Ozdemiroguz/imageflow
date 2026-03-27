import '../../../../core/enums/processing_type.dart';
import '../../../../core/error/result.dart';
import '../entities/processing_result.dart';
import '../entities/processing_step.dart';

part 'processing_repository_progress_callback_typedef.dart';

abstract class ProcessingRepository {
  Future<Result<ProcessingResult>> processImage({
    required String imagePath,
    ProcessingType? preferredType,
    ProgressCallback? onProgress,
    bool? capturedWithFrontCamera,
  });

  /// Alternative document flow for externally picked images.
  /// Uses native corner detection + perspective correction pipeline.
  Future<Result<ProcessingResult>> processImageExternal({
    required String imagePath,
    ProgressCallback? onProgress,
  });
}
