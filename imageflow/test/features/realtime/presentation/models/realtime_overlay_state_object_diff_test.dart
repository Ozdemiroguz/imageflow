import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imageflow/core/models/detected_object_info.dart';
import 'package:imageflow/features/realtime/presentation/models/capture_realtime_config.dart';
import 'package:imageflow/features/realtime/presentation/models/realtime_native_rotation_strategy.dart';
import 'package:imageflow/features/realtime/presentation/models/realtime_overlay_state.dart';

/// Locks the object-overlay change detection: the overlay must repaint on a
/// meaningful change (count, label, or a box that moved past the threshold) but
/// ignore sub-threshold jitter so it does not thrash on per-frame noise.
void main() {
  // A config with an explicit object-rect threshold so the test is independent
  // of the default value.
  const config = CaptureRealtimeConfig(
    realtimeStreamStartDelay: Duration.zero,
    resolutionPreset: ResolutionPreset.low,
    imageFormatGroup: ImageFormatGroup.bgra8888,
    nativeRotationStrategy: RealtimeNativeRotationStrategy.sensorOnly,
    frameImageUsesNativeRotation: false,
    minObjectRectDelta: 0.02,
  );

  final state = RealtimeOverlayState(config: config);

  DetectedObjectInfo obj({
    String label = 'cup',
    double left = 0.1,
    double top = 0.1,
    double right = 0.4,
    double bottom = 0.5,
  }) => DetectedObjectInfo(
    label: label,
    confidence: 0.9,
    rect: (left: left, top: top, right: right, bottom: bottom),
  );

  test('count change -> changed', () {
    expect(state.hasDetectedObjectsChanged([], [obj()]), isTrue);
    expect(state.hasDetectedObjectsChanged([obj()], []), isTrue);
  });

  test('label change at same box -> changed', () {
    expect(
      state.hasDetectedObjectsChanged(
        [obj(label: 'cup')],
        [obj(label: 'bowl')],
      ),
      isTrue,
    );
  });

  test('box moved past the threshold -> changed', () {
    expect(
      state.hasDetectedObjectsChanged([obj(left: 0.10)], [obj(left: 0.13)]),
      isTrue,
    );
  });

  test('sub-threshold jitter -> not changed', () {
    expect(
      state.hasDetectedObjectsChanged([obj(left: 0.100)], [obj(left: 0.110)]),
      isFalse,
    );
  });

  test('identical set -> not changed', () {
    expect(state.hasDetectedObjectsChanged([obj()], [obj()]), isFalse);
  });
}
