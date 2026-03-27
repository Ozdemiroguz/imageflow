import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../theme/context_theme_extensions.dart';

class MetadataChip extends StatelessWidget {
  const MetadataChip({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: context.tokens.spacingXs,
      children: [
        Icon(
          icon,
          size: 16,
          color: context.colors.onSurface.withValues(alpha: 0.4),
        ),
        Text(
          label,
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}
