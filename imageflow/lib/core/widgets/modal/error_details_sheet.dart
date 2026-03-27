import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../theme/context_theme_extensions.dart';
import '../design_system/app_primary_button.dart';

class ErrorDetailsSheet extends StatelessWidget {
  const ErrorDetailsSheet({
    super.key,
    required this.title,
    required this.code,
    required this.message,
    this.details,
    this.imagePath,
  });

  final String title;
  final String code;
  final String message;
  final String? details;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Padding(
      padding: EdgeInsets.all(tokens.spacingLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.text.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: tokens.spacingSm),
          SelectableText('Code: $code'),
          SizedBox(height: tokens.spacingXs),
          SelectableText('Message: $message'),
          if (details != null) ...[
            SizedBox(height: tokens.spacingXs),
            SelectableText('Details: $details'),
          ],
          if (imagePath != null) ...[
            SizedBox(height: tokens.spacingXs),
            SelectableText('Image: $imagePath'),
          ],
          SizedBox(height: tokens.spacingLg),
          Align(
            alignment: Alignment.centerRight,
            child: AppPrimaryButton.filled(
              onPressed: () => Navigator.of(context).pop(),
              label: 'Close',
            ),
          ),
        ],
      ),
    );
  }
}
