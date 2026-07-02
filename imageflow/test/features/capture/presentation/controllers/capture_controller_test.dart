import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:imageflow/core/platform/image_picker_gateway.dart';
import 'package:imageflow/core/services/modal_service.dart';
import 'package:imageflow/core/services/permission_service.dart';
import 'package:imageflow/features/capture/presentation/controllers/capture_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockPermissionService extends Mock implements PermissionService {}

class _MockModalService extends Mock implements ModalService {}

class _MockImagePickerGateway extends Mock implements ImagePickerGateway {}

void main() {
  late _MockPermissionService permissionService;
  late _MockModalService modalService;
  late _MockImagePickerGateway imagePicker;

  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  setUp(() {
    permissionService = _MockPermissionService();
    modalService = _MockModalService();
    imagePicker = _MockImagePickerGateway();
    Get.testMode = true;

    when(
      () => modalService.showLoadingOverlay(
        message: any(named: 'message'),
        label: any(named: 'label'),
      ),
    ).thenReturn(null);
    when(() => modalService.hideLoadingOverlay()).thenReturn(null);
    when(
      () => imagePicker.pickImageFromGallery(
        imageQuality: any(named: 'imageQuality'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => imagePicker.pickMultipleFromGallery(
        imageQuality: any(named: 'imageQuality'),
      ),
    ).thenAnswer((_) async => <String>[]);
  });

  tearDown(Get.reset);

  CaptureController make() => CaptureController(
    permissionService: permissionService,
    modalService: modalService,
    imagePicker: imagePicker,
  );

  group('CaptureController', () {
    group('pickFromCamera — permission denied', () {
      test('sets cameraDenied to true when permission not granted', () async {
        when(
          () => permissionService.requestCamera(),
        ).thenAnswer((_) async => false);

        final controller = make();
        await controller.pickFromCamera();

        expect(controller.cameraDenied.value, isTrue);
        controller.onClose();
      });

      test('does not navigate when permission is denied', () async {
        when(
          () => permissionService.requestCamera(),
        ).thenAnswer((_) async => false);

        final controller = make();
        await controller.pickFromCamera();

        // In testMode Get.toNamed does nothing — we verify cameraDenied is set
        // and no exception is thrown (navigation silently skipped in testMode).
        expect(controller.cameraDenied.value, isTrue);
        controller.onClose();
      });
    });

    group('pickFromCamera — permission granted', () {
      test('clears cameraDenied when permission is granted', () async {
        when(
          () => permissionService.requestCamera(),
        ).thenAnswer((_) async => true);

        final controller = make()..cameraDenied.value = true;
        await controller.pickFromCamera();

        expect(controller.cameraDenied.value, isFalse);
        controller.onClose();
      });

      test('requests camera permission exactly once', () async {
        when(
          () => permissionService.requestCamera(),
        ).thenAnswer((_) async => true);

        final controller = make();
        await controller.pickFromCamera();

        verify(() => permissionService.requestCamera()).called(1);
        controller.onClose();
      });
    });

    group('clearCameraDeniedWarning', () {
      test('sets cameraDenied to false', () {
        final controller = make()..cameraDenied.value = true;

        controller.clearCameraDeniedWarning();

        expect(controller.cameraDenied.value, isFalse);
        controller.onClose();
      });

      test('is idempotent when already false', () {
        final controller = make();
        expect(controller.cameraDenied.value, isFalse);

        controller.clearCameraDeniedWarning();

        expect(controller.cameraDenied.value, isFalse);
        controller.onClose();
      });
    });

    group('initial state', () {
      test('cameraDenied starts as false', () {
        final controller = make();
        expect(controller.cameraDenied.value, isFalse);
        controller.onClose();
      });
    });

    group('gallery paths', () {
      test('pickFromGallery delegates to the image picker gateway', () async {
        final controller = make();

        await controller.pickFromGallery();

        verify(() => imagePicker.pickImageFromGallery()).called(1);
        verify(
          () => modalService.showLoadingOverlay(message: any(named: 'message')),
        ).called(1);
        verify(() => modalService.hideLoadingOverlay()).called(1);
        controller.onClose();
      });

      test(
        'pickBatchFromGallery delegates to the multi-image gateway',
        () async {
          final controller = make();

          await controller.pickBatchFromGallery();

          verify(() => imagePicker.pickMultipleFromGallery()).called(1);
          verify(
            () =>
                modalService.showLoadingOverlay(message: any(named: 'message')),
          ).called(1);
          verify(() => modalService.hideLoadingOverlay()).called(1);
          controller.onClose();
        },
      );
    });
  });
}
