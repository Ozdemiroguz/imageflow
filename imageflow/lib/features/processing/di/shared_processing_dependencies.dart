import 'package:get/get.dart';

import '../../history/di/history_dependencies.dart';
import '../../history/domain/usecases/save_history.dart';
import '../domain/usecases/process_image.dart';
import 'processing_dependencies.dart';

/// Registers shared dependencies used by processing and batch routes.
void registerSharedProcessingDependencies() {
  registerHistoryDependencies();
  registerProcessingDependencies();

  if (!Get.isRegistered<ProcessImage>()) {
    Get.lazyPut<ProcessImage>(() => ProcessImage(Get.find()));
  }
  if (!Get.isRegistered<SaveHistory>()) {
    Get.lazyPut<SaveHistory>(() => SaveHistory(Get.find()));
  }
}
