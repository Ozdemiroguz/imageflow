import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_tokens.dart';
import '../controllers/processing_controller.dart';
import '../widgets/image_preview.dart';
import '../widgets/processing_error_view.dart';
import '../widgets/processing_progress_view.dart';

class ProcessingPage extends GetView<ProcessingController> {
  const ProcessingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Processing'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
          onPressed: Get.back,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(tokens.spacingLg),
          child: Column(
            children: [
              Expanded(
                flex: 3,
                child: ImagePreview(imagePath: controller.imagePath),
              ),
              SizedBox(height: tokens.spacingXl),
              Expanded(
                flex: 2,
                child: Obx(() {
                  final f = controller.failure.value;
                  if (f != null) {
                    return ProcessingErrorView(
                      failure: f,
                      onRetry: controller.retry,
                      onChooseNewImage: controller.chooseNewImage,
                    );
                  }
                  return ProcessingProgressView(
                    step: controller.currentStep.value,
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
