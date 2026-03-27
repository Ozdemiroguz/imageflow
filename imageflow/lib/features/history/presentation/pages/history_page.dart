import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/context_theme_extensions.dart';
import '../../../../core/widgets/design_system/app_primary_button.dart';
import '../controllers/history_controller.dart';
import '../widgets/empty_state.dart';
import '../widgets/gradient_fab.dart';
import '../widgets/history_list_item.dart';

class HistoryPage extends GetView<HistoryController> {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Scaffold(
      appBar: AppBar(title: const Text(AppConstants.appName)),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.failure.value != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: tokens.spacingLg,
              children: [
                Text(
                  controller.failure.value?.message ?? 'An unexpected error occurred.',
                  style: context.text.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                AppPrimaryButton.filled(
                  onPressed: controller.fetchHistory,
                  label: 'Retry',
                ),
              ],
            ),
          );
        }
        if (controller.historyList.isEmpty) {
          return const EmptyState();
        }
        return ListView.builder(
          itemCount: controller.historyList.length,
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacingLg,
            vertical: tokens.spacingSm,
          ),
          itemBuilder: (context, index) {
            final item = controller.historyList[index];
            return HistoryListItem(
              key: ValueKey(item.id),
              history: item,
              onConfirmDelete: controller.confirmDeleteHistory,
              onDismissed: () => controller.removeHistory(item.id),
              onOpenDetail: () => controller.openHistoryDetail(item),
            );
          },
        );
      }),
      floatingActionButton: GradientFab(
        onCapturePressed: controller.openCaptureDialog,
      ),
    );
  }
}
