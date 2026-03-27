import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/context_theme_extensions.dart';
import '../controllers/batch_processing_controller.dart';
import '../widgets/batch_body.dart';
import '../widgets/batch_bottom_bar.dart';

class BatchProcessingPage extends GetView<BatchProcessingController> {
  const BatchProcessingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final running = controller.isRunning.value;
      return PopScope(
        canPop: !running,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && running) {
            controller.requestStop();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Batch Processing'),
            leading: IconButton(
              icon: Icon(
                running
                    ? Icons.stop_circle_outlined
                    : Icons.arrow_back_outlined,
              ),
              tooltip: running ? 'Stop after current' : 'Back',
              onPressed: running
                  ? controller.requestStop
                  : () => controller.goHome(),
            ),
          ),
          body: BatchBody(controller: controller),
          bottomNavigationBar: BatchBottomBar(controller: controller),
          backgroundColor: context.colors.surfaceContainerLowest,
        ),
      );
    });
  }
}
