import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import 'batch_preview_card.dart';

class BatchSuccessPreviewRow extends StatelessWidget {
  const BatchSuccessPreviewRow({
    super.key,
    required this.originalPath,
    required this.processedPath,
  });

  final String originalPath;
  final String processedPath;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Row(
      children: [
        Expanded(
          child: BatchPreviewCard(label: 'Original', path: originalPath),
        ),
        SizedBox(width: tokens.spacingSm),
        Expanded(
          child: BatchPreviewCard(label: 'Processed', path: processedPath),
        ),
      ],
    );
  }
}
