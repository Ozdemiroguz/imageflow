import 'package:get/get.dart';

import '../../../../core/services/document_actions_presenter.dart';
import '../../../../core/services/modal_service.dart';
import '../../../../core/services/pdf_external_open_service.dart';
import '../../../../core/services/pdf_raster/pdf_raster_service.dart';
import '../controllers/history_detail_controller.dart';

class HistoryDetailBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HistoryDetailController>(
      () => HistoryDetailController(
        documentActions: DocumentActionsPresenter(
          modal: Get.find<ModalService>(),
          pdfExternalOpen: Get.find<PdfExternalOpenService>(),
        ),
        pdfRasterService: Get.find<PdfRasterService>(),
      ),
    );
  }
}
