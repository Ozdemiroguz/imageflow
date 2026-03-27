part of 'camera_capture_page.dart';

class _CameraErrorView extends StatelessWidget {
  const _CameraErrorView({
    required this.failure,
    required this.onRetry,
    this.onOpenSettings,
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
