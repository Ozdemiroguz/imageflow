import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/design_system/app_primary_button.dart';
import '../controllers/batch_processing_controller.dart';
import 'batch_action_buttons.dart';

class BatchBottomBar extends StatelessWidget {
  const BatchBottomBar({super.key, required this.controller});

  final BatchProcessingController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return SafeArea(
      minimum: EdgeInsets.fromLTRB(
        tokens.spacingLg,
        tokens.spacingSm,
        tokens.spacingLg,
        tokens.spacingLg,
      ),
      child: Obx(() {
        final failure = controller.failure.value;
        if (failure != null) return const SizedBox.shrink();

        final running = controller.isRunning.value;
        return running
            ? AppPrimaryButton.filled(
                onPressed: controller.requestStop,
                icon: controller.isStopping.value
                    ? Icons.hourglass_top
                    : Icons.stop_circle_outlined,
                label: controller.isStopping.value
                    ? 'Stopping...'
                    : 'Stop After Current',
                expand: true,
              )
            : BatchActionButtons(controller: controller);
      }),
    );
  }
}
