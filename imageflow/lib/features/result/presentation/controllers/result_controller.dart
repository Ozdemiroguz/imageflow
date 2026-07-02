import 'package:get/get.dart';

import '../../../../core/enums/processing_type.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/coordinators/document_actions_presenter.dart';
import '../../../../core/mappers/processing_history_mapper.dart';
import '../../../../core/services/pdf_raster/pdf_raster_service.dart';
import '../../../../core/widgets/pdf/pdf_viewer_controller.dart';
import '../../../history/domain/entities/processing_history.dart';
import '../../../processing/domain/entities/processing_result.dart';

class ResultController extends GetxController {
  ResultController({
    required DocumentActionsPresenter documentActions,
    required PdfRasterService pdfRasterService,
  }) : _documentActions = documentActions,
       _pdfRasterService = pdfRasterService;

  ProcessingResult? _result;
  final failure = Rxn<Failure>();
  final DocumentActionsPresenter _documentActions;
  final PdfRasterService _pdfRasterService;
  final _pdfViewerControllers = <String, PdfViewerController>{};

  /// The processed result. Only valid when [failure] is null (a bad route
  /// argument sets [failure] instead of assigning a result).
  ProcessingResult get result => _result!;

  bool get isFace => result.type == ProcessingType.face;
  bool get isDocument => result.type == ProcessingType.document;
  bool get hasPdf => (result.pdfPath ?? '').trim().isNotEmpty;

  PdfViewerController resolvePdfViewerController(String pdfPath) {
    return _pdfViewerControllers.putIfAbsent(
      pdfPath,
      () => PdfViewerController(
        rasterService: _pdfRasterService,
        pdfPath: pdfPath,
      ),
    );
  }

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    switch (args) {
      case ProcessingResult():
        _result = args;
      case ProcessingHistory():
        _result = ProcessingHistoryMapper.resultFromHistory(args);
      default:
        failure.value = const RouteArgumentFailure(
          'Expected ProcessingResult or ProcessingHistory',
        );
    }
  }

  Future<void> openPdfExternally() async {
    await _documentActions.openPdfExternally(result.pdfPath);
  }

  void showExtractedTextSheet() {
    _documentActions.showExtractedTextSheet(result.extractedText);
  }

  void goHome() {
    Get.offAllNamed(AppRoutes.home);
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
