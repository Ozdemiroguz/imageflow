import 'package:flutter/material.dart';

extension ContextThemeX on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get skeletonBlockColor => isDarkMode
      ? const Color(0xFF5F5F66).withValues(alpha: 0.58)
      : const Color(0xFFD3D3D8).withValues(alpha: 0.78);

  Color get skeletonShimmerBaseColor => isDarkMode
      ? const Color(0xFF696972).withValues(alpha: 0.64)
      : const Color(0xFFDCDCE1).withValues(alpha: 0.86);

  Color get skeletonShimmerHighlightColor => isDarkMode
      ? const Color(0xFF8D8D96).withValues(alpha: 0.78)
      : const Color(0xFFF1F1F4).withValues(alpha: 0.96);
}
