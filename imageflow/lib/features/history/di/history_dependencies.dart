import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';

import '../../../core/constants/storage_constants.dart';
import '../../../core/services/file_service.dart';
import '../data/repositories/history_repository_impl.dart';
import '../data/models/processing_history_model.dart';
import '../domain/repositories/history_repository.dart';

/// Registers Hive adapters and opens history box for History feature.
Future<void> ensureHistoryStorageReady() async {
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(ProcessingHistoryModelAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(ProcessingTypeModelAdapter());
  }
  if (!Hive.isBoxOpen(StorageConstants.historyBox)) {
    await Hive.openBox<ProcessingHistoryModel>(StorageConstants.historyBox);
  }
}

/// Registers History feature data dependencies.
void registerHistoryDependencies() {
  if (Get.isRegistered<HistoryRepository>()) return;

  if (!Hive.isBoxOpen(StorageConstants.historyBox)) {
    throw StateError(
      'History box is not initialized. Call ensureHistoryStorageReady() first.',
    );
  }

  Get.lazyPut<HistoryRepository>(
    () => HistoryRepositoryImpl(
      Hive.box<ProcessingHistoryModel>(StorageConstants.historyBox),
      Get.find<FileService>(),
    ),
  );
}
