import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../theme/context_theme_extensions.dart';
import '../design_system/app_primary_button.dart';

class PdfLoadError extends StatelessWidget {
  const PdfLoadError({
    super.key,
    required this.title,
    required this.message,
    required this.canRetry,
    required this.onRetry,
  });

  final String title;
  final String message;
  final bool canRetry;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: tokens.spacingSm,
          children: [
            Icon(
              Icons.picture_as_pdf_outlined,
              size: 40,
              color: context.colors.error,
            ),
            Text(
              title,
              style: context.text.titleMedium,
              textAlign: TextAlign.center,
            ),
            Text(
              message,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            if (canRetry)
              AppPrimaryButton.filled(
                onPressed: onRetry,
                icon: Icons.refresh,
                label: 'Retry',
              ),
          ],
        ),
      ),
    );
  }
}
