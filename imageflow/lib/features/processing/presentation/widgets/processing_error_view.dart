import 'package:flutter/material.dart';

import '../../../../core/error/failure_ui_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/context_theme_extensions.dart';
import '../../../../core/widgets/design_system/app_primary_button.dart';

class ProcessingErrorView extends StatelessWidget {
  const ProcessingErrorView({
    super.key,
    required this.failure,
    required this.onRetry,
    this.onChooseNewImage,
  });

  final Failure failure;
  final VoidCallback onRetry;
  final VoidCallback? onChooseNewImage;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;
    final ui = FailureUiMapper.map(failure);
    final isDetection = failure is DetectionFailure;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: tokens.spacingSm,
      children: [
        Icon(
          isDetection ? Icons.image_search : Icons.error_outline,
          size: 48,
          color: isDetection
              ? colors.onSurface.withValues(alpha: 0.5)
              : colors.error,
        ),
        Text(
          ui.title,
          style: context.text.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          ui.message,
          style: context.text.bodySmall?.copyWith(
            color: colors.onSurface.withValues(alpha: 0.5),
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: tokens.spacingMd),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: tokens.spacingSm,
          children: [
            if (onChooseNewImage != null)
              AppPrimaryButton.outlined(
                onPressed: onChooseNewImage,
                icon: Icons.add_photo_alternate_outlined,
                label: 'New Image',
              ),
            if (ui.canRetry)
              AppPrimaryButton.filled(
                onPressed: onRetry,
                icon: Icons.refresh,
                label: 'Retry',
              ),
          ],
        ),
      ],
    );
  }
}
