import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/design_system/app_primary_button.dart';
import '../controllers/batch_processing_controller.dart';

class BatchActionButtons extends StatelessWidget {
  const BatchActionButtons({super.key, required this.controller});

  final BatchProcessingController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.pendingCount > 0)
          AppPrimaryButton.filled(
            onPressed: controller.processPending,
            icon: Icons.play_arrow_outlined,
            label: controller.completedCount == 0 ? 'Start Queue' : 'Resume Queue',
            expand: true,
          ),
        if (controller.pendingCount > 0 && controller.failedCount > 0)
          SizedBox(height: tokens.spacingSm),
        if (controller.failedCount > 0)
          AppPrimaryButton.outlined(
            onPressed: controller.retryFailed,
            icon: Icons.refresh,
            label: 'Retry Failed (${controller.failedCount})',
            expand: true,
          ),
        SizedBox(height: tokens.spacingSm),
        AppPrimaryButton.filled(
          onPressed: controller.goHome,
          icon: Icons.check,
          label: 'Done',
          expand: true,
        ),
      ],
    );
  }
}
