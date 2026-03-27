import 'dart:ui';

import 'package:flutter/material.dart';

part 'app_tokens_build_context_extension.dart';
part 'app_tokens_spacing_extension.dart';

class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    this.radiusSm = 8.0,
    this.radiusMd = 12.0,
    this.radiusLg = 16.0,
    this.radiusXl = 24.0,
    this.radiusPill = 999.0,
    this.spacingXs = 4.0,
    this.spacingSm = 8.0,
    this.spacingMd = 12.0,
    this.spacingLg = 16.0,
    this.spacingXl = 24.0,
    this.spacingXxl = 32.0,
    this.spacingXxxl = 48.0,
    this.warning = const Color(0xFFE65100),
    this.success = const Color(0xFF2E7D32),
    this.info = const Color(0xFF1565C0),
    this.bonusYellow = const Color(0xFFFFD54F),
    this.realtimeDocumentStroke = const Color(0xFFF9A825),
    this.realtimeDocumentFill = const Color(0x22FFD54F),
    this.realtimeDocumentCorner = const Color(0xFFFFEE58),
    this.realtimeFaceStroke = const Color(0xDC00E676),
    this.realtimeFaceFill = const Color(0x2200E676),
  });

  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double radiusXl;
  final double radiusPill;
  final double spacingXs;
  final double spacingSm;
  final double spacingMd;
  final double spacingLg;
  final double spacingXl;
  final double spacingXxl;
  final double spacingXxxl;
  final Color warning;
  final Color success;
  final Color info;
  final Color bonusYellow;
  final Color realtimeDocumentStroke;
  final Color realtimeDocumentFill;
  final Color realtimeDocumentCorner;
  final Color realtimeFaceStroke;
  final Color realtimeFaceFill;

  @override
  AppTokens copyWith({
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusXl,
    double? radiusPill,
    double? spacingXs,
    double? spacingSm,
    double? spacingMd,
    double? spacingLg,
    double? spacingXl,
    double? spacingXxl,
    double? spacingXxxl,
    Color? warning,
    Color? success,
    Color? info,
    Color? bonusYellow,
    Color? realtimeDocumentStroke,
    Color? realtimeDocumentFill,
    Color? realtimeDocumentCorner,
    Color? realtimeFaceStroke,
    Color? realtimeFaceFill,
  }) {
    return AppTokens(
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusXl: radiusXl ?? this.radiusXl,
      radiusPill: radiusPill ?? this.radiusPill,
      spacingXs: spacingXs ?? this.spacingXs,
      spacingSm: spacingSm ?? this.spacingSm,
      spacingMd: spacingMd ?? this.spacingMd,
      spacingLg: spacingLg ?? this.spacingLg,
      spacingXl: spacingXl ?? this.spacingXl,
      spacingXxl: spacingXxl ?? this.spacingXxl,
      spacingXxxl: spacingXxxl ?? this.spacingXxxl,
      warning: warning ?? this.warning,
      success: success ?? this.success,
      info: info ?? this.info,
      bonusYellow: bonusYellow ?? this.bonusYellow,
      realtimeDocumentStroke:
          realtimeDocumentStroke ?? this.realtimeDocumentStroke,
      realtimeDocumentFill: realtimeDocumentFill ?? this.realtimeDocumentFill,
      realtimeDocumentCorner:
          realtimeDocumentCorner ?? this.realtimeDocumentCorner,
      realtimeFaceStroke: realtimeFaceStroke ?? this.realtimeFaceStroke,
      realtimeFaceFill: realtimeFaceFill ?? this.realtimeFaceFill,
    );
  }

  @override
  AppTokens lerp(AppTokens? other, double t) {
    if (other == null) return this;
    return AppTokens(
      radiusSm: lerpDouble(radiusSm, other.radiusSm, t) ?? radiusSm,
      radiusMd: lerpDouble(radiusMd, other.radiusMd, t) ?? radiusMd,
      radiusLg: lerpDouble(radiusLg, other.radiusLg, t) ?? radiusLg,
      radiusXl: lerpDouble(radiusXl, other.radiusXl, t) ?? radiusXl,
      radiusPill: lerpDouble(radiusPill, other.radiusPill, t) ?? radiusPill,
      spacingXs: lerpDouble(spacingXs, other.spacingXs, t) ?? spacingXs,
      spacingSm: lerpDouble(spacingSm, other.spacingSm, t) ?? spacingSm,
      spacingMd: lerpDouble(spacingMd, other.spacingMd, t) ?? spacingMd,
      spacingLg: lerpDouble(spacingLg, other.spacingLg, t) ?? spacingLg,
      spacingXl: lerpDouble(spacingXl, other.spacingXl, t) ?? spacingXl,
      spacingXxl: lerpDouble(spacingXxl, other.spacingXxl, t) ?? spacingXxl,
      spacingXxxl: lerpDouble(spacingXxxl, other.spacingXxxl, t) ?? spacingXxxl,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      success: Color.lerp(success, other.success, t) ?? success,
      info: Color.lerp(info, other.info, t) ?? info,
      bonusYellow: Color.lerp(bonusYellow, other.bonusYellow, t) ?? bonusYellow,
      realtimeDocumentStroke:
          Color.lerp(realtimeDocumentStroke, other.realtimeDocumentStroke, t) ??
          realtimeDocumentStroke,
      realtimeDocumentFill:
          Color.lerp(realtimeDocumentFill, other.realtimeDocumentFill, t) ??
          realtimeDocumentFill,
      realtimeDocumentCorner:
          Color.lerp(
            realtimeDocumentCorner,
            other.realtimeDocumentCorner,
            t,
          ) ??
          realtimeDocumentCorner,
      realtimeFaceStroke:
          Color.lerp(realtimeFaceStroke, other.realtimeFaceStroke, t) ??
          realtimeFaceStroke,
      realtimeFaceFill:
          Color.lerp(realtimeFaceFill, other.realtimeFaceFill, t) ??
          realtimeFaceFill,
    );
  }
}
