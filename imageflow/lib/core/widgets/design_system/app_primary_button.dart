import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../theme/context_theme_extensions.dart';
import 'app_primary_button_variant.dart';

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppPrimaryButtonVariant.filled,
    this.destructive = false,
    this.expand = false,
    this.icon,
  });

  const AppPrimaryButton.filled({
    super.key,
    required this.label,
    required this.onPressed,
    this.destructive = false,
    this.expand = false,
    this.icon,
  }) : variant = AppPrimaryButtonVariant.filled;

  const AppPrimaryButton.outlined({
    super.key,
    required this.label,
    required this.onPressed,
    this.destructive = false,
    this.expand = false,
    this.icon,
  }) : variant = AppPrimaryButtonVariant.outlined;

  final String label;
  final VoidCallback? onPressed;
  final AppPrimaryButtonVariant variant;
  final bool destructive;
  final bool expand;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;
    final textStyle = context.text.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
    );

    final child = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              SizedBox(width: tokens.spacingXs),
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    final horizontalPadding = EdgeInsets.symmetric(
      horizontal: tokens.spacingMd,
      vertical: tokens.spacingSm,
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(tokens.radiusMd),
    );

    final button = switch (variant) {
      AppPrimaryButtonVariant.filled => FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: horizontalPadding,
          backgroundColor: destructive ? colors.error : colors.primary,
          foregroundColor: destructive ? colors.onError : colors.onPrimary,
          textStyle: textStyle,
          shape: shape,
        ),
        child: child,
      ),
      AppPrimaryButtonVariant.outlined => OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: horizontalPadding,
          foregroundColor: destructive ? colors.error : colors.onSurface,
          side: BorderSide(
            color: destructive
                ? colors.error
                : colors.outline.withValues(alpha: 0.7),
          ),
          textStyle: textStyle,
          shape: shape,
        ),
        child: child,
      ),
    };

    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}
