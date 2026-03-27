import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';

class RealtimeFaceOverlayPainter extends CustomPainter {
  RealtimeFaceOverlayPainter({
    required this.faces,
    required AppTokens tokens,
  })  : _boxStroke = Paint()
          ..color = tokens.realtimeFaceStroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
        _boxFill = Paint()
          ..color = tokens.realtimeFaceFill
          ..style = PaintingStyle.fill;

  final List<Rect> faces;
  final Paint _boxStroke;
  final Paint _boxFill;

  @override
  void paint(Canvas canvas, Size size) {
    for (final face in faces) {
      final rect = Rect.fromLTWH(
        face.left * size.width,
        face.top * size.height,
        face.width * size.width,
        face.height * size.height,
      );
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(14));
      canvas.drawRRect(rrect, _boxFill);
      canvas.drawRRect(rrect, _boxStroke);
    }
  }

  @override
  bool shouldRepaint(covariant RealtimeFaceOverlayPainter oldDelegate) {
    return oldDelegate.faces != faces;
  }
}
