/// Recognized text in an image, expressed in plugin-free domain terms.
///
/// This is the anti-corruption boundary type for text recognition: the ML Kit
/// `RecognizedText` is mapped to this inside the detection service, so no layer
/// above the data source depends on `google_mlkit_text_recognition`.
class RecognizedTextData {
  const RecognizedTextData({required this.text, this.blockBoxes = const []});

  /// The full recognized text (may be empty).
  final String text;

  /// Pixel-space bounding boxes of each recognized text block, used to estimate
  /// a document crop region when native corner detection is unavailable.
  final List<TextBlockBox> blockBoxes;

  bool get isEmpty => text.isEmpty;
  bool get isNotEmpty => text.isNotEmpty;
}

/// Pixel-space bounding box of a single recognized text block.
typedef TextBlockBox = ({int left, int top, int right, int bottom});
