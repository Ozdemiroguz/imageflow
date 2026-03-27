import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/context_theme_extensions.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: tokens.spacingSm,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: context.colors.onSurface.withValues(alpha: 0.3),
            ),
            Text('No processed images yet', style: context.text.titleMedium),
            Text(
              'Tap the + button to capture or select an image',
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
