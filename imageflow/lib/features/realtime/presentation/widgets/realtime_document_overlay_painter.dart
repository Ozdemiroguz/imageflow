import 'package:flutter/material.dart';

import '../../../../core/models/normalized_corners.dart';
import '../../../../core/theme/app_tokens.dart';

class RealtimeDocumentOverlayPainter extends CustomPainter {
  RealtimeDocumentOverlayPainter({
    required this.corners,
    required AppTokens tokens,
  })  : _fill = Paint()
          ..color = tokens.realtimeDocumentFill
          ..style = PaintingStyle.fill,
        _stroke = Paint()
          ..color = tokens.realtimeDocumentStroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6,
        _corner = Paint()
          ..color = tokens.realtimeDocumentCorner
          ..style = PaintingStyle.fill;

  final NormalizedCorners? corners;
  final Paint _fill;
  final Paint _stroke;
  final Paint _corner;

  @override
  void paint(Canvas canvas, Size size) {
    final c = corners;
    if (c == null) return;

    final tl = Offset(c.topLeft.x * size.width, c.topLeft.y * size.height);
    final tr = Offset(c.topRight.x * size.width, c.topRight.y * size.height);
    final br = Offset(
      c.bottomRight.x * size.width,
      c.bottomRight.y * size.height,
    );
    final bl = Offset(
      c.bottomLeft.x * size.width,
      c.bottomLeft.y * size.height,
    );

    final path = Path()
      ..moveTo(tl.dx, tl.dy)
      ..lineTo(tr.dx, tr.dy)
      ..lineTo(br.dx, br.dy)
      ..lineTo(bl.dx, bl.dy)
      ..close();

    canvas.drawPath(path, _fill);
    canvas.drawPath(path, _stroke);

    const radius = 4.5;
    canvas.drawCircle(tl, radius, _corner);
    canvas.drawCircle(tr, radius, _corner);
    canvas.drawCircle(br, radius, _corner);
    canvas.drawCircle(bl, radius, _corner);
  }

  @override
  bool shouldRepaint(covariant RealtimeDocumentOverlayPainter oldDelegate) {
    return oldDelegate.corners != corners;
  }
}
