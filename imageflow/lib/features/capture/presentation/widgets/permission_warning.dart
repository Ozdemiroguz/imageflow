import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/context_theme_extensions.dart';

class PermissionWarning extends StatelessWidget {
  const PermissionWarning({
    super.key,
    required this.message,
    required this.onOpenSettings,
  });

  final String message;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;

    return Padding(
      padding: EdgeInsets.only(left: tokens.spacingLg, top: tokens.spacingXs),
      child: Row(
        spacing: tokens.spacingXs,
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: colors.error),
          Text(
            message,
            style: context.text.bodySmall?.copyWith(color: colors.error),
          ),
          GestureDetector(
            onTap: onOpenSettings,
            child: Text(
              'Open Settings',
              style: context.text.bodySmall?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
