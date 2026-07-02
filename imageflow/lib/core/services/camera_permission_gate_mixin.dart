import 'package:get/get.dart';

import '../error/failures.dart';
import 'permission_service.dart';

/// Shared camera-permission check for the camera session lifecycle classes.
///
/// The capture and realtime session managers had a byte-for-byte identical
/// permission routine: check (optionally request) the camera permission, mirror
/// the result into the UI's [cameraPermission] flag, and set/clear a
/// [PermissionFailure] on [cameraFailure]. This mixin holds that one routine;
/// each host supplies its own service and Rx state via the abstract members, so
/// the reactive state stays owned by the feature, not by this mixin.
mixin CameraPermissionGateMixin {
  PermissionService get permissionService;
  RxBool get cameraPermission;
  Rxn<Failure> get cameraFailure;

  /// Ensures camera permission, updating [cameraPermission] and clearing/setting
  /// a [PermissionFailure]. Returns whether permission is granted.
  Future<bool> ensureCameraPermission({required bool requestIfNeeded}) async {
    var granted = await permissionService.checkCameraPermission();
    if (!granted && requestIfNeeded) {
      granted = await permissionService.requestCamera();
    }

    cameraPermission.value = granted;
    if (!granted) {
      cameraFailure.value = const PermissionFailure(
        'Camera access is required. Please enable it in Settings.',
      );
    } else if (cameraFailure.value is PermissionFailure) {
      cameraFailure.value = null;
    }
    return granted;
  }
}
