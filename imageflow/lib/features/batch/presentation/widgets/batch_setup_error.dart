import 'package:flutter/material.dart';

import '../../../../core/error/failure_ui_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/context_theme_extensions.dart';
import '../../../../core/widgets/design_system/app_primary_button.dart';

class BatchSetupError extends StatelessWidget {
  const BatchSetupError({
    super.key,
    required this.failure,
    required this.onGoHome,
  });

  final Failure failure;
  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) {
    final ui = FailureUiMapper.map(failure);
    final tokens = context.tokens;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 52),
          SizedBox(height: tokens.spacingSm),
          Text(
            ui.title,
            style: context.text.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: tokens.spacingXs),
          Text(
            ui.message,
            textAlign: TextAlign.center,
            style: TextTheme.of(context).bodySmall,
          ),
          SizedBox(height: tokens.spacingLg),
          AppPrimaryButton.filled(
            onPressed: onGoHome,
            icon: Icons.home_outlined,
            label: 'Back to Home',
          ),
        ],
      ),
    );
  }
}
