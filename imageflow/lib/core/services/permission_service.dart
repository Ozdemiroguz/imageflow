import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService extends GetxService {
  Future<bool> requestCamera() async {
    final status = await Permission.camera.status;

    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) return false;

    final result = await Permission.camera.request();
    return result.isGranted;
  }

  Future<bool> requestPhotos() async {
    final status = await Permission.photos.status;

    if (status.isGranted || status.isLimited) return true;
    if (status.isPermanentlyDenied) return false;

    final result = await Permission.photos.request();
    return result.isGranted || result.isLimited;
  }

  Future<bool> get isCameraGranted => Permission.camera.isGranted;
  Future<bool> get isPhotosGranted => Permission.photos.isGranted;

  Future<bool> openSettings() => openAppSettings();
}
