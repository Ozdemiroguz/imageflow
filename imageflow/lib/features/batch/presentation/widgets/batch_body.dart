import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_tokens.dart';
import '../controllers/batch_processing_controller.dart';
import '../models/batch_item_state.dart';
import 'batch_item_tile.dart';
import 'batch_setup_error.dart';
import 'batch_summary_card.dart';

class BatchBody extends StatelessWidget {
  const BatchBody({super.key, required this.controller});

  final BatchProcessingController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacingLg),
        child: Obx(() {
          final failure = controller.failure.value;
          if (failure != null) {
            return BatchSetupError(
              failure: failure,
              onGoHome: controller.goHome,
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BatchSummaryCard(controller: controller),
              SizedBox(height: tokens.spacingMd),
              Expanded(
                child: Obx(() {
                  final running = controller.isRunning.value;
                  final items = List<BatchItemState>.unmodifiable(
                    controller.items,
                  );
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        SizedBox(height: tokens.spacingSm),
                    itemBuilder: (_, index) {
                      final item = items[index];
                      return BatchItemTile(
                        key: ValueKey(item.index),
                        controller: controller,
                        item: item,
                        fileName: controller.fileName(item),
                        isQueueRunning: running,
                      );
                    },
                  );
                }),
              ),
            ],
          );
        }),
      ),
    );
  }
}
