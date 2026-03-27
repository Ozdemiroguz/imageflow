import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/context_theme_extensions.dart';
import '../../../../core/widgets/design_system/app_primary_button.dart';
import '../controllers/batch_processing_controller.dart';
import '../models/batch_item_state.dart';
import '../models/batch_item_status.dart';
import 'batch_preview_card.dart';
import 'batch_success_preview_row.dart';

class BatchItemTile extends StatelessWidget {
  const BatchItemTile({
    super.key,
    required this.controller,
    required this.item,
    required this.fileName,
    required this.isQueueRunning,
  });

  final BatchProcessingController controller;
  final BatchItemState item;
  final String fileName;
  final bool isQueueRunning;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;
    final statusColor = _statusColor(item.status, colors, tokens);
    final subtitle = _subtitle(item);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  foregroundColor: statusColor,
                  child: Icon(_statusIcon(item.status)),
                ),
                SizedBox(width: tokens.spacingSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.index + 1}. $fileName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(
                          color: item.status == BatchItemStatus.failed
                              ? colors.error
                              : colors.onSurface.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: tokens.spacingSm),
                item.status == BatchItemStatus.running
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_statusIcon(item.status), color: statusColor),
              ],
            ),
            if (item.status == BatchItemStatus.success &&
                item.result != null) ...[
              SizedBox(height: tokens.spacingSm),
              BatchSuccessPreviewRow(
                originalPath: item.imagePath,
                processedPath: item.result!.processedImagePath,
              ),
              SizedBox(height: tokens.spacingXs),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => controller.openItemResult(item.index),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('View Detail'),
                ),
              ),
            ],
            if (item.status == BatchItemStatus.failed) ...[
              SizedBox(height: tokens.spacingSm),
              BatchPreviewCard(
                label: 'Original (Failed Item)',
                path: item.imagePath,
              ),
              SizedBox(height: tokens.spacingSm),
              Wrap(
                spacing: tokens.spacingSm,
                runSpacing: tokens.spacingSm,
                children: [
                  AppPrimaryButton.outlined(
                    onPressed: isQueueRunning
                        ? null
                        : () => controller.retryItem(item.index),
                    icon: Icons.refresh,
                    label: 'Retry',
                  ),
                  AppPrimaryButton.outlined(
                    onPressed: isQueueRunning
                        ? null
                        : () =>
                            controller.reselectItemFromGallery(item.index),
                    icon: Icons.photo_library_outlined,
                    label: 'Re-select',
                  ),
                  TextButton.icon(
                    onPressed: () => controller.showItemErrorDetails(item),
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('Details'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _subtitle(BatchItemState item) {
    return switch (item.status) {
      BatchItemStatus.pending => 'Queued',
      BatchItemStatus.running => item.step?.label ?? 'Processing...',
      BatchItemStatus.success => 'Processed successfully',
      BatchItemStatus.failed => () {
          final code = item.errorCode;
          if (code == null || code.isEmpty) {
            return item.errorMessage ?? 'Processing failed';
          }
          return '[$code] ${item.errorMessage ?? 'Processing failed'}';
        }(),
    };
  }

  IconData _statusIcon(BatchItemStatus status) {
    return switch (status) {
      BatchItemStatus.pending => Icons.schedule_outlined,
      BatchItemStatus.running => Icons.autorenew_outlined,
      BatchItemStatus.success => Icons.check_circle_outline,
      BatchItemStatus.failed => Icons.error_outline,
    };
  }

  Color _statusColor(
    BatchItemStatus status,
    ColorScheme colors,
    AppTokens tokens,
  ) {
    return switch (status) {
      BatchItemStatus.pending => colors.onSurface.withValues(alpha: 0.6),
      BatchItemStatus.running => tokens.info,
      BatchItemStatus.success => tokens.success,
      BatchItemStatus.failed => colors.error,
    };
  }
}
