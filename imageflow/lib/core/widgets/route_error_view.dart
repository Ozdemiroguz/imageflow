import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/context_theme_extensions.dart';
import 'design_system/app_primary_button.dart';

/// A full-screen error view for pages that received an invalid route argument
/// (or otherwise cannot render their content). Shared by result + history
/// detail, which both fall back to this when their route argument is missing.
class RouteErrorView extends StatelessWidget {
  const RouteErrorView({
    super.key,
    required this.message,
    required this.onDismiss,
    this.title = 'Something Went Wrong',
    this.dismissLabel = 'Go Home',
  });

  final String message;
  final String title;
  final String dismissLabel;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(tokens.spacingLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: tokens.spacingSm,
            children: [
              Icon(Icons.error_outline, size: 48, color: colors.error),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: tokens.spacingSm),
              AppPrimaryButton(label: dismissLabel, onPressed: onDismiss),
            ],
          ),
        ),
      ),
    );
  }
}
