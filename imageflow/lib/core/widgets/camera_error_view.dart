import 'package:flutter/material.dart';

import '../error/failure_ui_mapper.dart';
import '../error/failures.dart';
import '../theme/app_tokens.dart';
import 'design_system/app_primary_button.dart';

/// Full-bleed error overlay for camera screens (capture + realtime).
///
/// Renders the mapped [Failure] over a dark camera background, with a
/// permission-specific icon and an optional "Open Settings" action; a "Retry"
/// action appears when the failure is retryable or a permission issue. Shared
/// by both camera flows since their error UI is identical.
class CameraErrorView extends StatelessWidget {
  const CameraErrorView({
    required this.failure,
    required this.onRetry,
    this.onOpenSettings,
    super.key,
  });

  final Failure failure;
  final VoidCallback onRetry;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final ui = FailureUiMapper.map(failure);
    final isPermission = failure is PermissionFailure;
    final tokens = context.tokens;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacingXxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: tokens.spacingMd,
          children: [
            Icon(
              isPermission
                  ? Icons.no_photography_outlined
                  : Icons.videocam_off_outlined,
              size: 56,
              color: Colors.white54,
            ),
            Text(
              ui.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            Text(
              ui.message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white54),
              textAlign: TextAlign.center,
            ),
            if (isPermission && onOpenSettings != null) ...[
              tokens.spacingXs.verticalGap,
              AppPrimaryButton.outlined(
                onPressed: onOpenSettings,
                icon: Icons.settings_outlined,
                label: 'Open Settings',
              ),
            ],
            if (ui.canRetry || isPermission) ...[
              tokens.spacingXs.verticalGap,
              AppPrimaryButton.filled(
                onPressed: onRetry,
                icon: Icons.refresh,
                label: 'Retry',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
