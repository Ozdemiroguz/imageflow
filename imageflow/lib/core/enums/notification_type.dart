import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/context_theme_extensions.dart';

/// Notification variant for snackbar styling.
enum NotificationType {
  success(Icons.check_circle_outline),
  error(Icons.error_outline),
  info(Icons.info_outline),
  warning(Icons.warning_amber_outlined);

  const NotificationType(this.icon);

  final IconData icon;

  /// Resolves the background color from theme tokens.
  Color resolveBackground(BuildContext context) => switch (this) {
        success => context.tokens.success,
        error => context.colors.error,
        info => context.tokens.info,
        warning => context.tokens.warning,
      };

  /// Resolves the foreground color matching the background.
  Color resolveForeground(BuildContext context) => switch (this) {
        error => context.colors.onError,
        success || info || warning => Colors.white,
      };
}
