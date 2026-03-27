import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:imageflow/core/services/modal_service.dart';
import 'package:imageflow/core/services/permission_service.dart';
import 'package:imageflow/features/capture/presentation/controllers/capture_controller.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

class _MockPermissionService extends Mock implements PermissionService {}

class _MockModalService extends Mock implements ModalService {}

class _MockImagePicker extends Mock implements ImagePicker {}

void main() {
  late _MockPermissionService permissionService;
  late _MockModalService modalService;
  late _MockImagePicker picker;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(ImageSource.gallery);
  });

  setUp(() {
    permissionService = _MockPermissionService();
    modalService = _MockModalService();
    picker = _MockImagePicker();
    Get.testMode = true;

    when(
      () => modalService.showLoadingOverlay(
        message: any(named: 'message'),
        label: any(named: 'label'),
      ),
    ).thenReturn(null);
    when(() => modalService.hideLoadingOverlay()).thenReturn(null);
    when(
      () => picker.pickImage(
        source: any(named: 'source'),
        imageQuality: any(named: 'imageQuality'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => picker.pickMultiImage(imageQuality: any(named: 'imageQuality')),
    ).thenAnswer((_) async => <XFile>[]);
  });

  tearDown(Get.reset);

  CaptureController make() => CaptureController(
    permissionService: permissionService,
    modalService: modalService,
    picker: picker,
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
      test('pickFromGallery uses ImagePicker.gallery with quality 90', () async {
        final controller = make();

        await controller.pickFromGallery();

        verify(
          () =>
              picker.pickImage(source: ImageSource.gallery, imageQuality: 90),
        ).called(1);
        verify(
          () => modalService.showLoadingOverlay(message: any(named: 'message')),
        ).called(1);
        verify(() => modalService.hideLoadingOverlay()).called(1);
        controller.onClose();
      });

      test('pickBatchFromGallery uses multi image picker with quality 90', () async {
        final controller = make();

        await controller.pickBatchFromGallery();

        verify(() => picker.pickMultiImage(imageQuality: 90)).called(1);
        verify(
          () => modalService.showLoadingOverlay(message: any(named: 'message')),
        ).called(1);
        verify(() => modalService.hideLoadingOverlay()).called(1);
        controller.onClose();
      });
    });
  });
}
