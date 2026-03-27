import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../theme/context_theme_extensions.dart';

class AppIconInfoCard extends StatelessWidget {
  const AppIconInfoCard({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(tokens.spacingLg),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainer,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
      ),
      child: Row(
        spacing: tokens.spacingMd,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(tokens.radiusSm),
            ),
            child: Icon(icon, color: context.colors.primary),
          ),
          Expanded(
            child: Text(
              title,
              style: context.text.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          trailing ?? const SizedBox.shrink(),
        ],
      ),
    );
  }
}
