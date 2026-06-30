import '../../../../core/models/face_geometry.dart';

/// Annotates detected faces on an image: crops each face region, applies a
/// grayscale mask (contour polygon, or an oval fallback), draws the face
/// border, and writes the composited result to disk.
///
/// A domain-service contract so the heavy isolate/image work can be mocked when
/// testing the processing pipeline. Implementations live in the data layer.
abstract interface class FaceAnnotator {
  /// Reads [sourcePath], annotates each face given by [rects]/[contours]
  /// (index-aligned), and writes the result to [targetPath].
  Future<void> annotate({
    required String sourcePath,
    required String targetPath,
    required List<FaceRect> rects,
    required List<List<ContourPoint>> contours,
  });
}
