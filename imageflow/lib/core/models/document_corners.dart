/// 4 corner points of a detected document in pixel coordinates.
class DocumentCorners {
  const DocumentCorners({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  final ({double x, double y}) topLeft;
  final ({double x, double y}) topRight;
  final ({double x, double y}) bottomRight;
  final ({double x, double y}) bottomLeft;

  List<({double x, double y})> toList() =>
      [topLeft, topRight, bottomRight, bottomLeft];
}
