import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../theme/context_theme_extensions.dart';

class ExtractedTextSheet extends StatelessWidget {
  const ExtractedTextSheet({
    super.key,
    required this.text,
    this.title = 'Document Content',
  });

  final String text;
  final String title;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (sheetContext, scrollController) {
        final tokens = sheetContext.tokens;

        return Column(
          children: [
            Padding(
              padding: EdgeInsets.all(tokens.spacingLg),
              child: Row(
                children: [
                  Text(
                    title,
                    style: sheetContext.text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: EdgeInsets.all(tokens.spacingLg),
                child: SelectableText(
                  text,
                  style: sheetContext.text.bodyMedium,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
