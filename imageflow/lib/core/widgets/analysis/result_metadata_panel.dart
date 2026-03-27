import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_tokens.dart';
import '../../utils/file_utils.dart';
import 'metadata_chip.dart';

class ResultMetadataPanel extends StatelessWidget {
  const ResultMetadataPanel({
    super.key,
    required this.fileSize,
    required this.type,
    this.createdAt,
    this.id,
    this.showFileSize = true,
  });

  final int fileSize;
  final String type;
  final DateTime? createdAt;
  final String? id;
  final bool showFileSize;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      runAlignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: context.tokens.spacingLg,
      runSpacing: context.tokens.spacingSm,
      children: [
        if (showFileSize)
          MetadataChip(
            icon: Icons.straighten,
            label: FileUtils.formatFileSize(fileSize),
          ),
        MetadataChip(icon: Icons.category_outlined, label: type),
        if (createdAt != null)
          MetadataChip(
            icon: Icons.schedule_outlined,
            label: _formatDate(createdAt!),
          ),
        if (id != null && id!.isNotEmpty)
          MetadataChip(icon: Icons.tag_outlined, label: id!),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }
}
