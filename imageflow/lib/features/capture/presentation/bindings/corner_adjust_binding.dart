import 'package:get/get.dart';

import '../controllers/corner_adjust_controller.dart';

class CornerAdjustBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CornerAdjustController>(CornerAdjustController.new);
  }
}
