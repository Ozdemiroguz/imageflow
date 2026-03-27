import 'package:get/get.dart';

import '../../../../core/services/modal_service.dart';
import '../../../capture/presentation/actions/open_capture_dialog_action.dart';
import '../../di/history_dependencies.dart';
import '../../domain/usecases/delete_history.dart';
import '../../domain/usecases/get_all_history.dart';
import '../controllers/history_controller.dart';

class HistoryBinding implements Bindings {
  @override
  void dependencies() {
    registerHistoryDependencies();
    // Use Cases
    Get.lazyPut<GetAllHistory>(() => GetAllHistory(Get.find()));
    Get.lazyPut<DeleteHistory>(() => DeleteHistory(Get.find()));
    // Controllers
    Get.lazyPut<HistoryController>(
      () => HistoryController(
        getAllHistory: Get.find(),
        deleteHistory: Get.find(),
        modalService: Get.find<ModalService>(),
        openCaptureDialog: Get.find<OpenCaptureDialogAction>().open,
      ),
    );
  }
}
