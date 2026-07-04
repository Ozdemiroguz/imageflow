import 'package:flutter_test/flutter_test.dart';
import 'package:imageflow/features/realtime/presentation/models/realtime_detection_modes.dart';

void main() {
  test('defaults: all detectors enabled', () {
    const modes = RealtimeDetectionModes();
    expect(modes.face, isTrue);
    expect(modes.document, isTrue);
    expect(modes.object, isTrue);
    expect(modes.isNoneEnabled, isFalse);
  });

  test('copyWith toggles one flag, leaves others', () {
    const modes = RealtimeDetectionModes();
    final noFace = modes.copyWith(face: false);
    expect(noFace.face, isFalse);
    expect(noFace.document, isTrue);
    expect(noFace.object, isTrue);
  });

  test('isNoneEnabled is true only when all off', () {
    expect(
      const RealtimeDetectionModes(
        face: false,
        document: false,
        object: false,
      ).isNoneEnabled,
      isTrue,
    );
    expect(
      const RealtimeDetectionModes(
        face: false,
        document: false,
        object: true,
      ).isNoneEnabled,
      isFalse,
    );
  });

  test('value equality + hashCode', () {
    expect(
      const RealtimeDetectionModes(),
      equals(const RealtimeDetectionModes()),
    );
    expect(
      const RealtimeDetectionModes().hashCode,
      const RealtimeDetectionModes().hashCode,
    );
    expect(
      const RealtimeDetectionModes(face: false),
      isNot(equals(const RealtimeDetectionModes())),
    );
  });
}
