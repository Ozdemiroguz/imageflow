import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:imageflow/features/realtime/presentation/coordinators/realtime_frame_geometry_source.dart';

void main() {
  test('delegates every getter to its callback and sync() fires once', () {
    var syncCalls = 0;
    final source = RealtimeFrameGeometrySource(
      sync: () => syncCalls++,
      mlKitRotation: () => InputImageRotation.rotation270deg,
      nativeRotationDegrees: () => 90,
      frameImageRotationDegrees: () => 180,
      isFrontCamera: () => true,
      needsMirrorCompensation: () => false,
    );

    // Each getter must map to the correct callback — this locks against a
    // future edit accidentally swapping two of the six wires.
    expect(source.mlKitRotation, InputImageRotation.rotation270deg);
    expect(source.nativeRotationDegrees, 90);
    expect(source.frameImageRotationDegrees, 180);
    expect(source.isFrontCamera, isTrue);
    expect(source.needsMirrorCompensation, isFalse);

    expect(syncCalls, 0);
    source.sync();
    expect(syncCalls, 1);
  });
}
