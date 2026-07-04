import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imageflow/core/error/failures.dart';
import 'package:imageflow/core/error/result.dart';
import 'package:imageflow/core/models/detected_object_info.dart';
import 'package:imageflow/core/services/native_object_detection_service.dart';

/// Contract tests for [NativeObjectDetectionService] against a mocked platform
/// channel. They lock the Dart <-> native boundary: what the service sends over
/// the channel and how it maps the raw reply into [DetectedObjectInfo], without
/// a device or a real Core ML / MediaPipe backend.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.oguzhan.imageflow/object_detection');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late NativeObjectDetectionService service;
  late List<MethodCall> calls;

  setUp(() {
    service = NativeObjectDetectionService(channel: channel);
    calls = <MethodCall>[];
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  void stubReply(Object? reply) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return reply;
    });
  }

  void stubThrow(Object error) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      throw error;
    });
  }

  List<DetectedObjectInfo> okValue(Result<List<DetectedObjectInfo>> r) =>
      (r as Ok<List<DetectedObjectInfo>>).value;

  Failure errorFailure(Result<List<DetectedObjectInfo>> r) =>
      (r as Error<List<DetectedObjectInfo>>).failure;

  group('detectObjects (file path)', () {
    test(
      'maps a native reply into DetectedObjectInfo and returns Ok',
      () async {
        stubReply(<Map<Object?, Object?>>[
          {
            'label': 'cup',
            'confidence': 0.91,
            'left': 0.1,
            'top': 0.2,
            'right': 0.4,
            'bottom': 0.6,
            'trackingId': 7,
          },
        ]);

        final result = await service.detectObjects(imagePath: '/tmp/a.jpg');

        expect(result.isOk, isTrue);
        final objects = okValue(result);
        expect(objects, hasLength(1));
        final obj = objects.single;
        expect(obj.label, 'cup');
        expect(obj.confidence, closeTo(0.91, 1e-9));
        expect(obj.rect.left, 0.1);
        expect(obj.rect.bottom, 0.6);
        expect(obj.trackingId, 7);

        // Sent the image path under the documented method/argument.
        expect(calls.single.method, 'detectObjects');
        expect(calls.single.arguments, {'imagePath': '/tmp/a.jpg'});
      },
    );

    test('a null reply is a valid "no objects" outcome (Ok, empty)', () async {
      stubReply(null);

      final result = await service.detectObjects(imagePath: '/tmp/a.jpg');

      expect(result.isOk, isTrue);
      expect(okValue(result), isEmpty);
    });

    test('missing fields fall back to defaults', () async {
      stubReply(<Map<Object?, Object?>>[
        {'left': 0.0, 'top': 0.0, 'right': 0.5, 'bottom': 0.5},
      ]);

      final result = await service.detectObjects(imagePath: '/tmp/a.jpg');

      final obj = okValue(result).single;
      expect(obj.label, 'object');
      expect(obj.confidence, 0);
      expect(obj.trackingId, isNull);
    });

    test('a PlatformException becomes a NativeChannelFailure', () async {
      stubThrow(PlatformException(code: 'ERR', message: 'boom'));

      final result = await service.detectObjects(imagePath: '/tmp/a.jpg');

      expect(result.isError, isTrue);
      expect(errorFailure(result), isA<NativeChannelFailure>());
    });

    test('a MissingPluginException becomes a NativeChannelFailure', () async {
      // No handler registered → the platform throws MissingPluginException.
      messenger.setMockMethodCallHandler(channel, null);

      final result = await service.detectObjects(imagePath: '/tmp/a.jpg');

      expect(result.isError, isTrue);
      expect(errorFailure(result), isA<NativeChannelFailure>());
    });
  });

  group('detectObjectsFromFrame (hot path)', () {
    test('bgra frame sends bytes + bytesPerRow, maps the reply', () async {
      stubReply(<Map<Object?, Object?>>[
        {
          'label': 'laptop',
          'confidence': 0.8,
          'left': 0.0,
          'top': 0.0,
          'right': 1.0,
          'bottom': 1.0,
        },
      ]);

      final objects = await service.detectObjectsFromFrame(
        width: 640,
        height: 480,
        rotation: 90,
        bytes: Uint8List.fromList(const [1, 2, 3, 4]),
        bytesPerRow: 2560,
        format: 'bgra',
      );

      expect(objects, hasLength(1));
      expect(objects.single.label, 'laptop');

      final args = calls.single.arguments as Map;
      expect(calls.single.method, 'detectObjectsFromFrame');
      expect(args['width'], 640);
      expect(args['height'], 480);
      expect(args['rotation'], 90);
      expect(args['format'], 'bgra');
      expect(args['bytes'], isA<Uint8List>());
      expect(args['bytesPerRow'], 2560);
      // yuv-only keys must be absent on the bgra path.
      expect(args.containsKey('yBytes'), isFalse);
    });

    test('returns empty list on error (drop-frame semantics)', () async {
      stubThrow(PlatformException(code: 'ERR'));

      final objects = await service.detectObjectsFromFrame(
        width: 1,
        height: 1,
        rotation: 0,
        bytes: Uint8List.fromList(const [0]),
        bytesPerRow: 4,
      );

      expect(objects, isEmpty);
    });
  });
}
