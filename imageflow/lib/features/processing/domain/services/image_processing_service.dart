import '../../../../core/enums/processing_type.dart';
import '../../../../core/error/result.dart';
import '../../../../core/models/normalized_corners.dart';
import '../entities/processing_result.dart';
import '../entities/processing_step.dart';

part 'image_processing_service_progress_callback_typedef.dart';

/// Runs the image-processing pipeline (detect → annotate/crop → PDF →
/// thumbnail) and returns a [ProcessingResult].
///
/// This is a domain **service / interactor**, not a repository: it orchestrates
/// detection and cropping collaborators and performs no data persistence of its
/// own. Implementations live in the data layer.
abstract interface class ImageProcessingService {
  /// Processes [imagePath]. When [corners] is provided (from a manual
  /// corner-adjust screen) the document crop uses them instead of auto-detecting.
  Future<Result<ProcessingResult>> processImage({
    required String imagePath,
    ProcessingType? preferredType,
    ProgressCallback? onProgress,
    bool? capturedWithFrontCamera,
    NormalizedCorners? corners,
  });

  /// Alternative document flow for externally picked images.
  /// Uses native corner detection + perspective correction pipeline.
  Future<Result<ProcessingResult>> processImageExternal({
    required String imagePath,
    ProgressCallback? onProgress,
  });
}
