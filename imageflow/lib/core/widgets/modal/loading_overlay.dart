import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../theme/context_theme_extensions.dart';

class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    required this.message,
    this.label,
    this.showSpinner = true,
    super.key,
  });

  final String message;
  final String? label;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;

    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          margin: EdgeInsets.all(tokens.spacingLg),
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacingLg,
            vertical: tokens.spacingLg,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(tokens.radiusLg),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: tokens.spacingSm,
            children: [
              if (showSpinner)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              else
                Icon(Icons.open_in_new, size: 24, color: colors.primary),
              Text(
                message,
                style: context.text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              if (label != null && label!.trim().isNotEmpty)
                Text(
                  label!,
                  style: context.text.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.72),
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
