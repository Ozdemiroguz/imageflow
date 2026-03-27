import 'dart:async';

import 'package:get/get.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/modal_service.dart';
import '../../../../core/utils/log.dart';
import '../../domain/entities/processing_history.dart';
import '../../domain/usecases/delete_history.dart';
import '../../domain/usecases/get_all_history.dart';

class HistoryController extends GetxController {
  HistoryController({
    required GetAllHistory getAllHistory,
    required DeleteHistory deleteHistory,
    required ModalService modalService,
    required Future<void> Function() openCaptureDialog,
  }) : _getAllHistory = getAllHistory,
       _deleteHistory = deleteHistory,
       _modalService = modalService,
       _openCaptureDialog = openCaptureDialog;

  final GetAllHistory _getAllHistory;
  final DeleteHistory _deleteHistory;
  final ModalService _modalService;
  final Future<void> Function() _openCaptureDialog;

  final historyList = <ProcessingHistory>[].obs;
  final isLoading = false.obs;
  final failure = Rxn<Failure>();
  var _isOpeningDetail = false;

  @override
  void onInit() {
    super.onInit();
    fetchHistory();
  }

  Future<void> fetchHistory() async {
    isLoading.value = true;
    failure.value = null;
    final result = await _getAllHistory();
    switch (result) {
      case Ok(:final value):
        historyList.assignAll(value);
      case Error(:final failure):
        this.failure.value = failure;
    }
    isLoading.value = false;
  }

  Future<void> removeHistory(String id) async {
    final result = await _deleteHistory(id);
    switch (result) {
      case Ok():
        historyList.removeWhere((item) => item.id == id);
      case Error(:final failure):
        this.failure.value = failure;
    }
  }

  Future<bool> confirmDeleteHistory() {
    return _modalService.confirm(
      title: 'Delete',
      message: 'Are you sure you want to delete this item?',
    );
  }

  Future<void> openCaptureDialog() async {
    await _openCaptureDialog();
  }

  void openHistoryDetail(ProcessingHistory history) {
    if (_isOpeningDetail) {
      Log.debug(
        'Detail navigation ignored: already in progress. id=${history.id}',
        tag: 'HistoryDetailNav',
      );
      return;
    }
    _isOpeningDetail = true;
    final watch = Stopwatch()..start();

    Log.debug(
      'Detail navigation start. id=${history.id} type=${history.type.name} '
      'faces=${history.faceRects.length} hasPdf=${(history.pdfPath ?? '').trim().isNotEmpty}',
      tag: 'HistoryDetailNav',
    );

    final routeFuture = Get.toNamed(
      AppRoutes.historyDetail,
      arguments: history,
    );
    if (routeFuture != null) {
      unawaited(
        routeFuture.whenComplete(() {
          watch.stop();
          Log.debug(
            'Detail route closed. id=${history.id} '
            'elapsed=${watch.elapsedMilliseconds}ms',
            tag: 'HistoryDetailNav',
          );
          _isOpeningDetail = false;
        }),
      );
      return;
    }

    watch.stop();
    Log.warning(
      'Detail navigation returned null future. id=${history.id} '
      'elapsed=${watch.elapsedMilliseconds}ms',
      tag: 'HistoryDetailNav',
    );
    _isOpeningDetail = false;
  }
}
