part of 'face_swipe_comparison.dart';

class _RevealClipper extends CustomClipper<Rect> {
  const _RevealClipper(this.dx);

  final double dx;

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, dx.clamp(0, size.width), size.height);
  }

  @override
  bool shouldReclip(covariant _RevealClipper oldClipper) {
    return oldClipper.dx != dx;
  }
}
