/// A face detected in an image, expressed in plugin-free domain terms.
///
/// This is the anti-corruption boundary type for face detection: the ML Kit
/// `Face` is mapped to this inside the detection service, so no layer above
/// the data source depends on `google_mlkit_face_detection`.
class DetectedFace {
  const DetectedFace({required this.boundingBox, this.contour = const []});

  /// Pixel-space bounding box of the face.
  final FaceBoundingBox boundingBox;

  /// The face-outline contour points in pixel space (empty if unavailable).
  final List<FaceContourPoint> contour;
}

/// Pixel-space rectangle of a detected face.
typedef FaceBoundingBox = ({int left, int top, int right, int bottom});

/// A single pixel-space point on a face contour.
typedef FaceContourPoint = ({int x, int y});
