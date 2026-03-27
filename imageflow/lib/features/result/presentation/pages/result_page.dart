import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/result_controller.dart';
import '../widgets/document_result_layout.dart';
import '../widgets/face_result_layout.dart';

class ResultPage extends GetView<ResultController> {
  const ResultPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) controller.goHome();
      },
      child: controller.isDocument
          ? DocumentResultLayout(controller: controller)
          : FaceResultLayout(controller: controller),
    );
  }
}
