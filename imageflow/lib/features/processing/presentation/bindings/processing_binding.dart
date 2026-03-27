import 'package:get/get.dart';

import '../../di/shared_processing_dependencies.dart';
import '../controllers/processing_controller.dart';
import '../mappers/processing_history_mapper.dart';

class ProcessingBinding implements Bindings {
  @override
  void dependencies() {
    registerSharedProcessingDependencies();
    Get.lazyPut<ProcessingHistoryMapper>(ProcessingHistoryMapper.new);

    Get.lazyPut<ProcessingController>(
      () => ProcessingController(
        processImage: Get.find(),
        saveHistory: Get.find(),
        historyMapper: Get.find(),
      ),
    );
  }
}
