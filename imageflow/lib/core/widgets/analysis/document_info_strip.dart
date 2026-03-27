import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../theme/context_theme_extensions.dart';
import '../../utils/file_utils.dart';
import 'metadata_chip.dart';

class DocumentInfoStrip extends StatelessWidget {
  const DocumentInfoStrip({
    super.key,
    required this.fileSize,
    required this.extractedTextLength,
    required this.extractedText,
    required this.onViewExtractedText,
  });

  final int fileSize;
  final int extractedTextLength;
  final String? extractedText;
  final VoidCallback onViewExtractedText;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final hasText = extractedText != null && extractedText!.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacingLg,
        vertical: tokens.spacingMd,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(
          top: BorderSide(
            color: context.colors.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          MetadataChip(
            icon: Icons.straighten,
            label: FileUtils.formatFileSize(fileSize),
          ),
          SizedBox(width: tokens.spacingLg),
          if (extractedTextLength > 0)
            MetadataChip(
              icon: Icons.text_fields,
              label: '$extractedTextLength chars',
            ),
          const Spacer(),
          if (hasText)
            TextButton.icon(
              onPressed: onViewExtractedText,
              icon: const Icon(Icons.article_outlined, size: 18),
              label: const Text('View Content'),
            ),
        ],
      ),
    );
  }
}
