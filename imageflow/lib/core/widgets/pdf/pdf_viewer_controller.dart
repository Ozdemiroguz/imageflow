import 'dart:async';
import 'dart:typed_data';

import 'package:get/get.dart';

import '../../error/failures.dart';
import '../../error/result.dart';
import '../../services/pdf_raster/pdf_raster_service.dart';

class PdfViewerController {
  PdfViewerController({
    required PdfRasterService rasterService,
    required String pdfPath,
  }) : _rasterService = rasterService,
       _pdfPath = pdfPath;

  final PdfRasterService _rasterService;
  final String _pdfPath;

  final pages = <Uint8List>[].obs;
  final currentPage = 0.obs;
  final isLoading = true.obs;
  final failure = Rxn<Failure>();
  final isReady = false.obs;

  int get totalPages => pages.length;

  Future<void>? _activeLoad;
  bool _disposed = false;

  Future<void> ensureLoaded() {
    if (isReady.value && _activeLoad == null) {
      return Future.value();
    }
    if (_activeLoad != null) {
      return _activeLoad!;
    }
    return load();
  }

  Future<void> load({bool forceRefresh = false}) async {
    if (_disposed) return;
    if (!forceRefresh && _activeLoad != null) {
      await _activeLoad;
      return;
    }

    final completer = Completer<void>();
    _activeLoad = completer.future;

    isLoading.value = true;
    failure.value = null;
    if (forceRefresh) {
      _rasterService.invalidate(_pdfPath);
    }

    final result = await _rasterService.rasterize(
      pdfPath: _pdfPath,
      forceRefresh: forceRefresh,
    );

    if (_disposed) {
      if (!completer.isCompleted) {
        completer.complete();
      }
      _activeLoad = null;
      return;
    }

    try {
      switch (result) {
        case Ok(:final value):
          pages.assignAll(value);
          currentPage.value = 0;
        case Error(:final failure):
          this.failure.value = failure;
          pages.clear();
          currentPage.value = 0;
      }
      isReady.value = true;
      isLoading.value = false;
    } finally {
      if (!completer.isCompleted) {
        completer.complete();
      }
      if (identical(_activeLoad, completer.future)) {
        _activeLoad = null;
      }
    }
  }

  String pageLabel(int index) {
    return 'Page ${index + 1}';
  }

  void dispose() {
    _disposed = true;
    _activeLoad = null;
    pages.clear();
    currentPage.value = 0;
    isLoading.value = false;
  }
}
