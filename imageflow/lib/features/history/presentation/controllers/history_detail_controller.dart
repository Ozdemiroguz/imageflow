import 'package:get/get.dart';

import '../../../../core/enums/processing_type.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/log.dart';
import '../../../../core/services/document_actions_presenter.dart';
import '../../../../core/services/pdf_raster/pdf_raster_service.dart';
import '../../../../core/widgets/pdf/pdf_viewer_controller.dart';
import '../../domain/entities/processing_history.dart';

class HistoryDetailController extends GetxController {
  HistoryDetailController({
    required DocumentActionsPresenter documentActions,
    required PdfRasterService pdfRasterService,
  }) : _documentActions = documentActions,
       _pdfRasterService = pdfRasterService;

  late final ProcessingHistory history;
  final DocumentActionsPresenter _documentActions;
  final PdfRasterService _pdfRasterService;
  final _pdfViewerControllers = <String, PdfViewerController>{};

  bool get isFace => history.type == ProcessingType.face;
  bool get isDocument => history.type == ProcessingType.document;

  bool get hasPdf {
    final path = history.pdfPath;
    return path != null && path.trim().isNotEmpty;
  }

  PdfViewerController resolvePdfViewerController(String pdfPath) {
    return _pdfViewerControllers.putIfAbsent(
      pdfPath,
      () => PdfViewerController(rasterService: _pdfRasterService, pdfPath: pdfPath),
    );
  }

  @override
  void onInit() {
    super.onInit();
    final watch = Stopwatch()..start();
    final args = Get.arguments;
    if (args is! ProcessingHistory) {
      throw const RouteArgumentFailure('Expected ProcessingHistory');
    }
    history = args;
    watch.stop();
    Log.debug(
      'Detail controller initialized. id=${history.id} type=${history.type.name} '
      'faces=${history.faceRects.length} hasPdf=${(history.pdfPath ?? '').trim().isNotEmpty} '
      'init=${watch.elapsedMilliseconds}ms',
      tag: 'HistoryDetail',
    );
  }

  Future<void> openPdfExternally() async {
    await _documentActions.openPdfExternally(history.pdfPath);
  }

  void showExtractedTextSheet() {
    _documentActions.showExtractedTextSheet(history.extractedText);
  }

  @override
  void onClose() {
    for (final controller in _pdfViewerControllers.values) {
      controller.dispose();
    }
    _pdfViewerControllers.clear();
    super.onClose();
  }
}
