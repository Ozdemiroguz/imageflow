import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:imageflow/core/enums/processing_type.dart';
import 'package:imageflow/core/error/failures.dart';
import 'package:imageflow/core/error/result.dart';
import 'package:imageflow/core/services/modal_service.dart';
import 'package:imageflow/features/history/domain/entities/processing_history.dart';
import 'package:imageflow/features/history/domain/usecases/delete_history.dart';
import 'package:imageflow/features/history/domain/usecases/get_all_history.dart';
import 'package:imageflow/features/history/presentation/controllers/history_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetAllHistory extends Mock implements GetAllHistory {}

class _MockDeleteHistory extends Mock implements DeleteHistory {}

class _MockModalService extends Mock implements ModalService {}

ProcessingHistory _fakeHistory({
  String id = 'h1',
  ProcessingType type = ProcessingType.face,
}) => ProcessingHistory(
  id: id,
  originalImagePath: '/o/$id.jpg',
  processedImagePath: '/p/$id.jpg',
  type: type,
  createdAt: DateTime(2024),
  fileSizeBytes: 1024,
);

void main() {
  late _MockGetAllHistory getAllHistory;
  late _MockDeleteHistory deleteHistory;
  late _MockModalService modalService;
  late Future<void> Function() openCaptureDialog;
  var openCaptureDialogCallCount = 0;

  setUp(() {
    getAllHistory = _MockGetAllHistory();
    deleteHistory = _MockDeleteHistory();
    modalService = _MockModalService();
    openCaptureDialogCallCount = 0;
    openCaptureDialog = () async {
      openCaptureDialogCallCount += 1;
    };
  });

  tearDown(Get.reset);

  // Helper: creates controller and manually triggers onInit (GetX requires
  // the controller to be put into the GetX container to call onInit).
  Future<HistoryController> makeAndInit() async {
    when(() => getAllHistory()).thenAnswer((_) async => Result.ok([]));
    final controller = HistoryController(
      getAllHistory: getAllHistory,
      deleteHistory: deleteHistory,
      modalService: modalService,
      openCaptureDialog: openCaptureDialog,
    );
    controller.onInit();
    await pumpEventQueue();
    return controller;
  }

  group('HistoryController', () {
    group('fetchHistory', () {
      test('isLoading is false after fetch completes', () async {
        final controller = await makeAndInit();
        expect(controller.isLoading.value, isFalse);
        controller.onClose();
      });

      test('populates historyList on Ok result', () async {
        when(() => getAllHistory()).thenAnswer(
          (_) async =>
              Result.ok([_fakeHistory(id: 'a'), _fakeHistory(id: 'b')]),
        );
        final controller = HistoryController(
          getAllHistory: getAllHistory,
          deleteHistory: deleteHistory,
          modalService: modalService,
          openCaptureDialog: openCaptureDialog,
        );
        controller.onInit();
        await pumpEventQueue();

        expect(controller.historyList.length, 2);
        controller.onClose();
      });

      test('sets failure.value on Error result', () async {
        when(
          () => getAllHistory(),
        ).thenAnswer((_) async => Result.error(const StorageFailure()));
        final controller = HistoryController(
          getAllHistory: getAllHistory,
          deleteHistory: deleteHistory,
          modalService: modalService,
          openCaptureDialog: openCaptureDialog,
        );
        controller.onInit();
        await pumpEventQueue();

        expect(controller.failure.value, isA<StorageFailure>());
        controller.onClose();
      });

      test('clears previous failure before re-fetch', () async {
        // First fetch fails
        when(
          () => getAllHistory(),
        ).thenAnswer((_) async => Result.error(const StorageFailure()));
        final controller = HistoryController(
          getAllHistory: getAllHistory,
          deleteHistory: deleteHistory,
          modalService: modalService,
          openCaptureDialog: openCaptureDialog,
        );
        controller.onInit();
        await pumpEventQueue();
        expect(controller.failure.value, isNotNull);

        // Second fetch succeeds → failure cleared
        when(() => getAllHistory()).thenAnswer((_) async => Result.ok([]));
        await controller.fetchHistory();

        expect(controller.failure.value, isNull);
        controller.onClose();
      });

      test('calls getAllHistory on onInit', () async {
        when(() => getAllHistory()).thenAnswer((_) async => Result.ok([]));
        final controller = HistoryController(
          getAllHistory: getAllHistory,
          deleteHistory: deleteHistory,
          modalService: modalService,
          openCaptureDialog: openCaptureDialog,
        );
        controller.onInit();
        await pumpEventQueue();

        verify(() => getAllHistory()).called(1);
        controller.onClose();
      });
    });

    group('removeHistory', () {
      test('removes item from historyList on Ok', () async {
        when(() => getAllHistory()).thenAnswer(
          (_) async =>
              Result.ok([_fakeHistory(id: 'keep'), _fakeHistory(id: 'del')]),
        );
        when(
          () => deleteHistory('del'),
        ).thenAnswer((_) async => Result.ok(null));

        final controller = HistoryController(
          getAllHistory: getAllHistory,
          deleteHistory: deleteHistory,
          modalService: modalService,
          openCaptureDialog: openCaptureDialog,
        );
        controller.onInit();
        await pumpEventQueue();
        await controller.removeHistory('del');

        expect(controller.historyList.any((h) => h.id == 'del'), isFalse);
        expect(controller.historyList.any((h) => h.id == 'keep'), isTrue);
        controller.onClose();
      });

      test('sets failure.value on Error', () async {
        when(() => getAllHistory()).thenAnswer((_) async => Result.ok([]));
        when(
          () => deleteHistory('bad'),
        ).thenAnswer((_) async => Result.error(const StorageFailure()));

        final controller = await makeAndInit();
        await controller.removeHistory('bad');

        expect(controller.failure.value, isA<StorageFailure>());
        controller.onClose();
      });

      test('does not remove item from list on Error', () async {
        when(
          () => getAllHistory(),
        ).thenAnswer((_) async => Result.ok([_fakeHistory(id: 'h1')]));
        when(
          () => deleteHistory('h1'),
        ).thenAnswer((_) async => Result.error(const StorageFailure()));

        final controller = HistoryController(
          getAllHistory: getAllHistory,
          deleteHistory: deleteHistory,
          modalService: modalService,
          openCaptureDialog: openCaptureDialog,
        );
        controller.onInit();
        await pumpEventQueue();
        await controller.removeHistory('h1');

        expect(controller.historyList.length, 1);
        controller.onClose();
      });
    });

    group('confirmDeleteHistory', () {
      test('delegates to modalService.confirm and returns true', () async {
        when(
          () => modalService.confirm(
            title: 'Delete',
            message: 'Are you sure you want to delete this item?',
          ),
        ).thenAnswer((_) async => true);

        final controller = await makeAndInit();
        final confirmed = await controller.confirmDeleteHistory();

        expect(confirmed, isTrue);
        verify(
          () => modalService.confirm(
            title: 'Delete',
            message: 'Are you sure you want to delete this item?',
          ),
        ).called(1);
        controller.onClose();
      });

      test('returns false when user cancels', () async {
        when(
          () => modalService.confirm(
            title: any(named: 'title'),
            message: any(named: 'message'),
          ),
        ).thenAnswer((_) async => false);

        final controller = await makeAndInit();
        final confirmed = await controller.confirmDeleteHistory();

        expect(confirmed, isFalse);
        controller.onClose();
      });
    });

    group('openCaptureDialog', () {
      test('delegates to injected capture callback', () async {
        final controller = await makeAndInit();
        await controller.openCaptureDialog();

        expect(openCaptureDialogCallCount, 1);
        controller.onClose();
      });
    });
  });
}
