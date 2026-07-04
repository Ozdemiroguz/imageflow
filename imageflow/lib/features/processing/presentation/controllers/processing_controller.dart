import 'dart:async';

import 'package:get/get.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../history/domain/usecases/save_history.dart';
import '../../domain/entities/processing_step.dart';
import '../../domain/usecases/process_image.dart';
import '../../../../core/mappers/processing_history_mapper.dart';

class ProcessingController extends GetxController {
  ProcessingController({
    required ProcessImage processImage,
    required SaveHistory saveHistory,
    required ProcessingHistoryMapper historyMapper,
    Duration startupDelay = AppConstants.routeTransitionSettleDelay,
  }) : _processImage = processImage,
       _saveHistory = saveHistory,
       _historyMapper = historyMapper,
       _startupDelay = startupDelay;

  final ProcessImage _processImage;
  final SaveHistory _saveHistory;
  final ProcessingHistoryMapper _historyMapper;
  final Duration _startupDelay;

  final currentStep = ProcessingStep.copying.obs;
  final isProcessing = false.obs;
  final failure = Rxn<Failure>();

  bool get isDetectionError => failure.value is DetectionFailure;

  late final String _imagePath;
  bool? _capturedWithFrontCamera;

  String get imagePath => _imagePath;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is Map<String, dynamic>) {
      _imagePath = args['imagePath'] is String
          ? args['imagePath'] as String
          : args['imagePath'].toString();
      final capturedWithFrontCamera = args['capturedWithFrontCamera'];
      _capturedWithFrontCamera = capturedWithFrontCamera is bool
          ? capturedWithFrontCamera
          : null;
    } else if (args is String) {
      _imagePath = args;
      _capturedWithFrontCamera = null;
    } else {
      _imagePath = args.toString();
      _capturedWithFrontCamera = null;
    }
    // Show the progress state immediately, but defer the pipeline (file copy,
    // ML Kit model load, isolates) until the entrance transition settles —
    // 350ms is imperceptible against a multi-second pipeline, and the push
    // animation stays smooth.
    isProcessing.value = true;
    unawaited(_startAfterTransition());
  }

  Future<void> _startAfterTransition() async {
    if (_startupDelay > Duration.zero) {
      await Future<void>.delayed(_startupDelay);
      if (isClosed) return;
    }
    await _startProcessing();
  }

  Future<void> _startProcessing() async {
    isProcessing.value = true;
    failure.value = null;

    final outcome = _capturedWithFrontCamera == null
        ? await _processImage(imagePath: _imagePath, onProgress: _onProgress)
        : await _processImage(
            imagePath: _imagePath,
            onProgress: _onProgress,
            capturedWithFrontCamera: _capturedWithFrontCamera,
          );

    if (isClosed) return;

    switch (outcome) {
      case Ok(:final value):
        final saveResult = await _saveHistory(
          _historyMapper.toPersisted(value),
        );
        if (isClosed) return;

        switch (saveResult) {
          case Ok():
            isProcessing.value = false;
            await Get.offNamed(AppRoutes.result, arguments: value);
          case Error(:final failure):
            this.failure.value = failure;
            isProcessing.value = false;
        }
      case Error(:final failure):
        this.failure.value = failure;
        isProcessing.value = false;
    }
  }

  Future<void> retry() async {
    failure.value = null;
    currentStep.value = ProcessingStep.copying;
    await _startProcessing();
  }

  void chooseNewImage() {
    // Close any active snackbar before rebuilding the stack — navigating over
    // an open snackbar corrupts GetX's navigator state.
    if (Get.isSnackbarOpen) {
      Get.closeAllSnackbars();
    }
    Get.offAllNamed(AppRoutes.home);
  }

  void _onProgress(ProcessingStep step) {
    if (isClosed) return;
    currentStep.value = step;
  }
}
