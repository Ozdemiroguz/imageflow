import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/context_theme_extensions.dart';
import '../controllers/batch_processing_controller.dart';
import 'queue_status.dart';
import 'queue_status_chip.dart';
import 'summary_stat_tile.dart';

class BatchSummaryCard extends StatelessWidget {
  const BatchSummaryCard({super.key, required this.controller});

  final BatchProcessingController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final tokens = context.tokens;
      final colors = context.colors;
      final total = controller.totalCount;
      final completed = controller.completedCount;
      final progress = controller.progress;
      final progressText = '${(progress * 100).round()}%';
      final queueStatus = _queueStatus(colors, tokens);

      return Card(
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.surfaceContainerHigh.withValues(alpha: 0.45),
                colors.surfaceContainer.withValues(alpha: 0.30),
              ],
            ),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.25),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(tokens.spacingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Queue Summary',
                      style: context.text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    QueueStatusChip(status: queueStatus),
                  ],
                ),
                SizedBox(height: tokens.spacingMd),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$completed / $total',
                            style: context.text.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'items completed',
                            style: context.text.labelMedium?.copyWith(
                              color: colors.onSurface.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      progressText,
                      style: context.text.titleLarge?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.spacingSm),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  backgroundColor: colors.surfaceContainerHighest.withValues(
                    alpha: 0.55,
                  ),
                ),
                SizedBox(height: tokens.spacingMd),
                Wrap(
                  spacing: tokens.spacingSm,
                  runSpacing: tokens.spacingSm,
                  children: [
                    SummaryStatTile(
                      icon: Icons.check_circle_outline,
                      label: 'Success',
                      value: controller.successCount.toString(),
                      color: tokens.success,
                    ),
                    SummaryStatTile(
                      icon: Icons.error_outline,
                      label: 'Failed',
                      value: controller.failedCount.toString(),
                      color: colors.error,
                    ),
                    SummaryStatTile(
                      icon: Icons.schedule_outlined,
                      label: 'Pending',
                      value: controller.pendingCount.toString(),
                      color: colors.onSurface.withValues(alpha: 0.75),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  QueueStatus _queueStatus(ColorScheme colors, AppTokens tokens) {
    if (controller.isRunning.value) {
      if (controller.isStopping.value) {
        return QueueStatus(
          label: 'Stopping',
          icon: Icons.hourglass_top,
          color: tokens.warning,
        );
      }
      return QueueStatus(
        label: 'Running',
        icon: Icons.autorenew_outlined,
        color: tokens.info,
      );
    }

    if (controller.pendingCount == 0) {
      if (controller.failedCount == 0) {
        return QueueStatus(
          label: 'Completed',
          icon: Icons.check_circle_outline,
          color: tokens.success,
        );
      }
      return QueueStatus(
        label: 'Finished',
        icon: Icons.error_outline,
        color: colors.error,
      );
    }

    return QueueStatus(
      label: 'Ready',
      icon: Icons.play_arrow_outlined,
      color: colors.onSurface.withValues(alpha: 0.75),
    );
  }
}
