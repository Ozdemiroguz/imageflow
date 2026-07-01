import 'package:get/get.dart';

import '../../../../core/enums/processing_type.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/log.dart';
import '../../../../core/coordinators/document_actions_presenter.dart';
import '../../../../core/services/pdf_raster/pdf_raster_service.dart';
import '../../../../core/widgets/pdf/pdf_viewer_controller.dart';
import '../../domain/entities/processing_history.dart';

class HistoryDetailController extends GetxController {
  HistoryDetailController({
    required DocumentActionsPresenter documentActions,
    required PdfRasterService pdfRasterService,
  }) : _documentActions = documentActions,
       _pdfRasterService = pdfRasterService;

  ProcessingHistory? _history;
  final failure = Rxn<Failure>();
  final DocumentActionsPresenter _documentActions;
  final PdfRasterService _pdfRasterService;
  final _pdfViewerControllers = <String, PdfViewerController>{};

  /// The history record. Only valid when [failure] is null (a bad route
  /// argument sets [failure] instead of assigning a record).
  ProcessingHistory get history => _history!;

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
    final args = Get.arguments;
    if (args is! ProcessingHistory) {
      failure.value = const RouteArgumentFailure('Expected ProcessingHistory');
      return;
    }
    _history = args;
    Log.debug(
      'Detail controller initialized. id=${history.id} type=${history.type.name} '
      'faces=${history.faceRects.length} hasPdf=${(history.pdfPath ?? '').trim().isNotEmpty}',
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
