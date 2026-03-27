import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/context_theme_extensions.dart';
import '../../domain/entities/processing_step.dart';

class ProcessingProgressView extends StatelessWidget {
  const ProcessingProgressView({super.key, required this.step});

  final ProcessingStep step;

  /// Whether we're in document flow (detected by step type).
  bool get _isDocumentFlow => switch (step) {
    ProcessingStep.detectingText ||
    ProcessingStep.correctingPerspective ||
    ProcessingStep.enhancingContrast ||
    ProcessingStep.generatingPdf => true,
    _ => false,
  };

  double get _progress =>
      _isDocumentFlow ? step.documentProgress : step.faceProgress;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: tokens.spacingLg,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            step.label,
            key: ValueKey(step),
            style: context.text.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radiusSm),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: _progress),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              builder: (_, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: context.colors.surfaceContainer,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.burrowingOwl,
                ),
              ),
            ),
          ),
        ),
        Text(
          '${(_progress * 100).round()}%',
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}
