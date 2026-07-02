import 'package:get/get.dart';

import '../../../../core/services/file_service.dart';
import '../../di/shared_processing_dependencies.dart';
import '../controllers/processing_controller.dart';
import '../../../../core/mappers/processing_history_mapper.dart';

class ProcessingBinding implements Bindings {
  @override
  void dependencies() {
    registerSharedProcessingDependencies();
    Get.lazyPut<ProcessingHistoryMapper>(
      () => ProcessingHistoryMapper(fileService: Get.find<FileService>()),
    );

    Get.lazyPut<ProcessingController>(
      () => ProcessingController(
        processImage: Get.find(),
        saveHistory: Get.find(),
        historyMapper: Get.find(),
      ),
    );
  }
}
