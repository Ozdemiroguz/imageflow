import 'package:flutter/material.dart';

import '../../../../core/models/detected_object_info.dart';
import '../../../../core/theme/app_tokens.dart';

/// Draws COCO-labeled object boxes over the camera preview: a rounded box plus
/// a small label chip (`label 87%`) anchored to the box's top-left.
///
/// Coordinates arrive normalized (0-1) and are scaled to the paint [Size].
class RealtimeObjectOverlayPainter extends CustomPainter {
  RealtimeObjectOverlayPainter({
    required this.objects,
    required AppTokens tokens,
    this.mirrorLabels = false,
  }) : _labelBg = tokens.realtimeObjectLabelBg,
       _boxStroke = Paint()
         ..color = tokens.realtimeObjectStroke
         ..style = PaintingStyle.stroke
         ..strokeWidth = 2.2,
       _boxFill = Paint()
         ..color = tokens.realtimeObjectFill
         ..style = PaintingStyle.fill,
       _labelBgPaint = Paint()
         ..color = tokens.realtimeObjectLabelBg
         ..style = PaintingStyle.fill;

  final List<DetectedObjectInfo> objects;

  /// When the preview is horizontally flipped (front camera), the label text
  /// would render mirrored. Setting this re-flips just the label glyphs so the
  /// text stays readable while the boxes keep their (already-flipped) positions.
  final bool mirrorLabels;
  final Color _labelBg;
  final Paint _boxStroke;
  final Paint _boxFill;
  final Paint _labelBgPaint;

  static const _labelPadH = 6.0;
  static const _labelPadV = 3.0;
  static const _labelTextStyle = TextStyle(
    color: Colors.white,
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  @override
  void paint(Canvas canvas, Size size) {
    for (final object in objects) {
      final rect = Rect.fromLTRB(
        object.rect.left * size.width,
        object.rect.top * size.height,
        object.rect.right * size.width,
        object.rect.bottom * size.height,
      );
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
      canvas.drawRRect(rrect, _boxFill);
      canvas.drawRRect(rrect, _boxStroke);

      _paintLabel(canvas, size, rect, object);
    }
  }

  void _paintLabel(
    Canvas canvas,
    Size size,
    Rect box,
    DetectedObjectInfo object,
  ) {
    final percent = (object.confidence.clamp(0, 1) * 100).round();
    final painter = TextPainter(
      text: TextSpan(text: '${object.label} $percent%', style: _labelTextStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final chipWidth = painter.width + _labelPadH * 2;
    final chipHeight = painter.height + _labelPadV * 2;

    // Anchor above the box; if it would clip off the top, drop it inside.
    var chipTop = box.top - chipHeight;
    if (chipTop < 0) chipTop = box.top;
    var chipLeft = box.left;
    if (chipLeft + chipWidth > size.width) {
      chipLeft = size.width - chipWidth;
    }
    if (chipLeft < 0) chipLeft = 0;

    final chipRect = Rect.fromLTWH(chipLeft, chipTop, chipWidth, chipHeight);

    if (mirrorLabels) {
      // Re-flip only this chip around its own center so, once the parent's
      // front-camera flip is applied, the text reads left-to-right again.
      canvas.save();
      canvas.translate(chipRect.center.dx, 0);
      canvas.scale(-1, 1);
      canvas.translate(-chipRect.center.dx, 0);
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(chipRect, const Radius.circular(6)),
      _labelBgPaint,
    );
    painter.paint(canvas, Offset(chipLeft + _labelPadH, chipTop + _labelPadV));

    if (mirrorLabels) canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RealtimeObjectOverlayPainter oldDelegate) {
    return oldDelegate.objects != objects ||
        oldDelegate.mirrorLabels != mirrorLabels ||
        oldDelegate._labelBg != _labelBg;
  }
}
