part of 'detected_faces_strip.dart';

class _FaceThumbnailInput {
  const _FaceThumbnailInput({required this.rect, required this.contour});

  final ({int left, int top, int width, int height}) rect;
  final List<({int x, int y})> contour;
}

const _thumbLogTag = 'DetectedFacesStrip';

List<Uint8List> _buildFaceThumbnails(
  String imagePath,
  List<_FaceThumbnailInput> inputs,
) {
  final normalizedInputs = inputs
      .map((input) => (rect: input.rect, contour: input.contour))
      .toList(growable: false);
  return FaceThumbnailBuilder.build(
    imagePath: imagePath,
    inputs: normalizedInputs,
    logTag: _thumbLogTag,
  );
}
