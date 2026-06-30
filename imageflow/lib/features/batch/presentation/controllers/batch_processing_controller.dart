import 'package:get/get.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/platform/image_picker_gateway.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/file_service.dart';
import '../../../../core/models/snack_data.dart';
import '../../../../core/services/modal_service.dart';
import '../../../../core/utils/perf_trace.dart';
import '../../../history/domain/usecases/save_history.dart';
import '../../../processing/domain/entities/processing_result.dart';
import '../../../processing/domain/usecases/process_image.dart';
import '../../../processing/presentation/mappers/processing_history_mapper.dart';
import '../../services/batch_item_state_manager.dart';
import '../../services/batch_queue_initializer.dart';
import '../../services/batch_run_metrics_tracker.dart';
import '../models/batch_item_state.dart';
import '../models/batch_item_status.dart';

class BatchProcessingController extends GetxController {
  BatchProcessingController({
    required ProcessImage processImage,
    required SaveHistory saveHistory,
    required FileService fileService,
    required ModalService modalService,
    required ImagePickerGateway imagePicker,
    BatchQueueInitializer queueInitializer = const BatchQueueInitializer(),
    ProcessingHistoryMapper? historyMapper,
  }) : _processImage = processImage,
       _saveHistory = saveHistory,
       _modalService = modalService,
       _imagePicker = imagePicker,
       _queueInitializer = queueInitializer,
       _historyMapper =
           historyMapper ??
           ProcessingHistoryMapper(fileService: fileService);

  final ProcessImage _processImage;
  final SaveHistory _saveHistory;
  final ModalService _modalService;
  final ImagePickerGateway _imagePicker;
  final BatchQueueInitializer _queueInitializer;
  final ProcessingHistoryMapper _historyMapper;
  final BatchItemStateManager _itemState = const BatchItemStateManager();
  final BatchRunMetricsTracker _runMetrics = BatchRunMetricsTracker();

  final items = <BatchItemState>[].obs;
  final failure = Rxn<Failure>();
  final isRunning = false.obs;
  final isStopping = false.obs;

  bool _stopRequested = false;

  int get totalCount => items.length;
  int get pendingCount =>
      items.where((item) => item.status == BatchItemStatus.pending).length;
  int get successCount =>
      items.where((item) => item.status == BatchItemStatus.success).length;
  int get failedCount =>
      items.where((item) => item.status == BatchItemStatus.failed).length;
  int get completedCount => successCount + failedCount;
  double get progress => totalCount == 0 ? 0 : completedCount / totalCount;

  @override
  void onInit() {
    super.onInit();
    _initializeQueue();
  }

  @override
  void onReady() {
    super.onReady();
    if (failure.value == null && items.isNotEmpty) {
      Future<void>.microtask(processPending);
    }
  }

  Future<void> processPending() async {
    if (isRunning.value || items.isEmpty) return;
    _beginRun();

    try {
      for (var i = 0; i < items.length; i++) {
        if (items[i].status != BatchItemStatus.pending) continue;
        await _processItemAt(i);
        if (_stopRequested || isClosed) break;
      }
    } finally {
      _endRun();
    }

    if (!isClosed && pendingCount == 0) {
      if (failedCount == 0) {
        _modalService.showSnack(
          SnackData.success(
            title: 'Batch Completed',
            message: '$successCount image(s) processed successfully.',
          ),
        );
      } else {
        _modalService.showSnack(
          SnackData.warning(
            title: 'Batch Finished',
            message: '$successCount success, $failedCount failed.',
          ),
        );
      }
    }
  }

  Future<void> retryFailed() async {
    if (isRunning.value || failedCount == 0) return;

    for (var i = 0; i < items.length; i++) {
      if (items[i].status == BatchItemStatus.failed) {
        _itemState.toPending(items, i);
      }
    }

    await processPending();
  }

  Future<void> retryItem(int index) async {
    if (isRunning.value || index < 0 || index >= items.length) return;
    if (items[index].status != BatchItemStatus.failed) return;

    _itemState.toPending(items, index);

    await _runSinglePending(index);
  }

  Future<void> reselectItemFromGallery(int index) async {
    if (isRunning.value || index < 0 || index >= items.length) return;

    final imagePath = await _imagePicker.pickImageFromGallery();
    if (imagePath == null) return;

    _itemState.toPending(items, index, imagePath: imagePath);

    await _runSinglePending(index);
  }

  void requestStop() {
    if (!isRunning.value) return;
    _stopRequested = true;
    isStopping.value = true;
  }

  Future<void> goHome() async {
    await Get.offAllNamed(AppRoutes.home);
  }

  Future<void> openItemResult(int index) async {
    if (index < 0 || index >= items.length) return;
    final item = items[index];
    if (item.status != BatchItemStatus.success || item.result == null) return;

    await Get.toNamed(
      AppRoutes.historyDetail,
      arguments: _historyMapper.toDetail(item.result!),
    );
  }

  Future<void> showItemErrorDetails(BatchItemState item) {
    return _modalService.showErrorDetailsSheet(
      code: item.errorCode,
      message: item.errorMessage,
      details: item.errorDetails,
      imagePath: item.imagePath,
      fallbackMessage: 'Processing failed.',
    );
  }

  String fileName(BatchItemState item) {
    final normalized = item.imagePath.replaceAll('\\', '/');
    return normalized.split('/').last;
  }

  void _beginRun() {
    isRunning.value = true;
    isStopping.value = false;
    _stopRequested = false;
    _runMetrics.begin();
  }

  void _endRun() {
    if (isClosed) return;
    _runMetrics.finish(pendingCount: pendingCount);
    isRunning.value = false;
    isStopping.value = false;
  }

  Future<void> _runSinglePending(int index) async {
    if (isRunning.value || index < 0 || index >= items.length) return;
    if (items[index].status != BatchItemStatus.pending) return;

    _beginRun();
    try {
      await _processItemAt(index);
    } finally {
      _endRun();
    }
  }

  Future<void> _processItemAt(int itemIndex) async {
    if (itemIndex < 0 || itemIndex >= items.length) return;
    final itemWatch = PerfTrace.start();
    final current = items[itemIndex];
    if (current.status != BatchItemStatus.pending) {
      PerfTrace.stopMs(itemWatch);
      return;
    }

    _itemState.toRunning(items, itemIndex);

    final outcome = await _processImage(
      imagePath: current.imagePath,
      onProgress: (step) {
        if (isClosed || itemIndex < 0 || itemIndex >= items.length) return;
        if (items[itemIndex].status != BatchItemStatus.running) return;
        _itemState.withProgress(items, itemIndex, step);
      },
    );
    if (isClosed || itemIndex < 0 || itemIndex >= items.length) {
      PerfTrace.stopMs(itemWatch);
      return;
    }

    switch (outcome) {
      case Ok(:final value):
        await _handleSuccess(itemIndex, value);
      case Error(:final failure):
        _markFailed(itemIndex, failure);
    }

    if (itemIndex < 0 || itemIndex >= items.length) {
      PerfTrace.stopMs(itemWatch);
      return;
    }

    _runMetrics.recordItem(
      itemIndex: itemIndex,
      status: items[itemIndex].status,
      elapsedMs: PerfTrace.stopMs(itemWatch),
    );
  }

  Future<void> _handleSuccess(int itemIndex, ProcessingResult result) async {
    final saveResult = await _saveHistory(_historyMapper.toPersisted(result));
    if (isClosed) return;

    switch (saveResult) {
      case Ok():
        _itemState.toSuccess(items, itemIndex, result);
      case Error(:final failure):
        _markFailed(itemIndex, failure);
    }
  }

  void _markFailed(int itemIndex, Failure failure) {
    if (itemIndex < 0 || itemIndex >= items.length) return;
    _itemState.toFailure(items, itemIndex, failure);
  }

  void _initializeQueue() {
    final queueResult = _queueInitializer.build(Get.arguments);
    switch (queueResult) {
      case Ok(:final value):
        items.assignAll(value);
      case Error(:final failure):
        this.failure.value = failure;
    }
  }
}
