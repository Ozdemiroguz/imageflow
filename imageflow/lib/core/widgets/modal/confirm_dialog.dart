import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../theme/app_tokens.dart';
import '../../theme/context_theme_extensions.dart';
import '../design_system/app_primary_button.dart';

class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Delete',
    this.cancelLabel = 'Cancel',
    this.isDestructive = true,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final accent = isDestructive
        ? context.colors.error
        : context.colors.primary;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: tokens.spacingLg),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusLg),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacingLg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accent.withValues(alpha: 0.38),
                    width: 1.2,
                  ),
                ),
                child: Icon(
                  isDestructive
                      ? Icons.delete_forever_outlined
                      : Icons.help_outline,
                  size: 32,
                  color: accent,
                ),
              ),
              SizedBox(height: tokens.spacingMd),
              Text(
                title,
                textAlign: TextAlign.center,
                style: context.text.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: tokens.spacingXs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurface.withValues(alpha: 0.84),
                ),
              ),
              SizedBox(height: tokens.spacingLg),
              Row(
                children: [
                  Expanded(
                    child: AppPrimaryButton.outlined(
                      label: cancelLabel,
                      onPressed: () => Get.back(result: false),
                    ),
                  ),
                  SizedBox(width: tokens.spacingSm),
                  Expanded(
                    child: AppPrimaryButton.filled(
                      label: confirmLabel,
                      onPressed: () => Get.back(result: true),
                      destructive: isDestructive,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
