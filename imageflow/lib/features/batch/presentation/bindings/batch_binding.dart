import 'package:get/get.dart';

import '../../../../core/services/file_service.dart';
import '../../../../core/services/modal_service.dart';
import '../../../processing/di/shared_processing_dependencies.dart';
import '../controllers/batch_processing_controller.dart';

class BatchBinding implements Bindings {
  @override
  void dependencies() {
    registerSharedProcessingDependencies();

    Get.lazyPut<BatchProcessingController>(
      () => BatchProcessingController(
        processImage: Get.find(),
        saveHistory: Get.find(),
        fileService: Get.find<FileService>(),
        modalService: Get.find<ModalService>(),
      ),
    );
  }
}
