import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/error/failure_ui_mapper.dart';
import '../../../../core/widgets/route_error_view.dart';
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
      child: Obx(() {
        final failure = controller.failure.value;
        if (failure != null) {
          return RouteErrorView(
            title: 'Unable to Show Result',
            message: FailureUiMapper.map(failure).message,
            onDismiss: controller.goHome,
          );
        }
        return controller.isDocument
            ? DocumentResultLayout(controller: controller)
            : FaceResultLayout(controller: controller);
      }),
    );
  }
}
