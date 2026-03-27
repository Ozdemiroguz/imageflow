import 'package:get/get.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

class StorageService extends GetxService {
  Future<StorageService> init() async {
    await Hive.initFlutter();
    return this;
  }

  @override
  void onClose() {
    Hive.close();
    super.onClose();
  }
}
