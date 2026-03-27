/// 4 corner points in normalized 0-1 coordinates (for realtime overlay).
class NormalizedCorners {
  const NormalizedCorners({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  final ({double x, double y}) topLeft;
  final ({double x, double y}) topRight;
  final ({double x, double y}) bottomRight;
  final ({double x, double y}) bottomLeft;
}
