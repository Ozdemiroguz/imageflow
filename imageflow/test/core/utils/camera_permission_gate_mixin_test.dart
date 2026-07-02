import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:imageflow/core/error/failures.dart';
import 'package:imageflow/core/utils/camera_permission_gate_mixin.dart';
import 'package:imageflow/core/services/permission_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockPermissionService extends Mock implements PermissionService {}

/// Minimal host that mixes in the gate, exposing the Rx state the mixin drives.
class _Host with CameraPermissionGateMixin {
  _Host(this.permissionService);

  @override
  final PermissionService permissionService;
  @override
  final RxBool cameraPermission = false.obs;
  @override
  final Rxn<Failure> cameraFailure = Rxn<Failure>();
}

void main() {
  late _MockPermissionService permission;
  late _Host host;

  setUp(() {
    permission = _MockPermissionService();
    host = _Host(permission);
  });

  test('granted: flag true, PermissionFailure cleared', () async {
    host.cameraFailure.value = const PermissionFailure('stale');
    when(
      () => permission.checkCameraPermission(),
    ).thenAnswer((_) async => true);

    final granted = await host.ensureCameraPermission(requestIfNeeded: true);

    expect(granted, isTrue);
    expect(host.cameraPermission.value, isTrue);
    expect(host.cameraFailure.value, isNull);
  });

  test('denied: flag false, PermissionFailure set', () async {
    when(
      () => permission.checkCameraPermission(),
    ).thenAnswer((_) async => false);
    when(() => permission.requestCamera()).thenAnswer((_) async => false);

    final granted = await host.ensureCameraPermission(requestIfNeeded: true);

    expect(granted, isFalse);
    expect(host.cameraPermission.value, isFalse);
    expect(host.cameraFailure.value, isA<PermissionFailure>());
  });

  test('requestIfNeeded=false does not request when not granted', () async {
    when(
      () => permission.checkCameraPermission(),
    ).thenAnswer((_) async => false);

    final granted = await host.ensureCameraPermission(requestIfNeeded: false);

    expect(granted, isFalse);
    verifyNever(() => permission.requestCamera());
  });

  test('does not clobber a non-permission failure when granted', () async {
    host.cameraFailure.value = const CameraFailure('camera broke');
    when(
      () => permission.checkCameraPermission(),
    ).thenAnswer((_) async => true);

    await host.ensureCameraPermission(requestIfNeeded: false);

    // Only PermissionFailure is cleared; other failures are left intact.
    expect(host.cameraFailure.value, isA<CameraFailure>());
  });
}
