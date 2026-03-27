import 'package:flutter/material.dart';

abstract class AppColors {
  // Primary - Warm Coral Family
  static const tawnyOwl = Color(0xFFF1947B);
  static const greatHornedOwl = Color(0xFFED6F72);
  static const burrowingOwl = Color(0xFFEA4F6C);

  // Secondary - Cool Muted Family
  static const screechOwl = Color(0xFF994164);
  static const greatGreyOwl = Color(0xFF484C6D);
  static const elfOwl = Color(0xFF1F1D2F);

  // Foundation
  static const bgPrimary = Color(0xFF12121A);
  static const bgSecondary = Color(0xFF1A1A24);
  static const bgElevated = Color(0xFF22222E);

  // Gradient
  static const primaryGradient = LinearGradient(
    colors: [burrowingOwl, greatHornedOwl],
  );
}
