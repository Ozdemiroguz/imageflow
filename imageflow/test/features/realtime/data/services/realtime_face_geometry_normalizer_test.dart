import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imageflow/features/realtime/data/services/realtime_face_geometry_normalizer.dart';
import 'package:mocktail/mocktail.dart';

class _MockCameraImage extends Mock implements CameraImage {}

CameraImage _frame({int width = 100, int height = 200}) {
  final frame = _MockCameraImage();
  when(() => frame.width).thenReturn(width);
  when(() => frame.height).thenReturn(height);
  return frame;
}

void main() {
  group('selectPrimaryFaceIndex', () {
    const normalizer = RealtimeFaceGeometryNormalizer(
      frameImageUsesNativeRotation: false,
    );

    test('returns 0 for empty or single face', () {
      expect(normalizer.selectPrimaryFaceIndex(const []), 0);
      expect(
        normalizer.selectPrimaryFaceIndex([
          const Rect.fromLTWH(0, 0, 10, 10),
        ]),
        0,
      );
    });

    test('picks the largest-area face', () {
      final faces = [
        const Rect.fromLTWH(0, 0, 10, 10), // area 100
        const Rect.fromLTWH(0, 0, 30, 30), // area 900  ← primary
        const Rect.fromLTWH(0, 0, 20, 20), // area 400
      ];
      expect(normalizer.selectPrimaryFaceIndex(faces), 1);
    });
  });

  group('normalizeFaceRect', () {
    // frameImageUsesNativeRotation:false → oriented size == raw frame size.
    const normalizer = RealtimeFaceGeometryNormalizer(
      frameImageUsesNativeRotation: false,
    );

    test('maps pixel rect to 0..1 space', () {
      final result = normalizer.normalizeFaceRect(
        const Rect.fromLTWH(25, 50, 50, 50), // in a 100x200 frame
        _frame(width: 100, height: 200),
        nativeRotationDegrees: 0,
        needsMirrorCompensation: false,
      );

      expect(result, isNotNull);
      expect(result!.left, closeTo(0.25, 1e-9));
      expect(result.top, closeTo(0.25, 1e-9));
      expect(result.right, closeTo(0.75, 1e-9));
      expect(result.bottom, closeTo(0.5, 1e-9));
    });

    test('mirror compensation flips horizontally around 0.5', () {
      final result = normalizer.normalizeFaceRect(
        const Rect.fromLTWH(0, 0, 25, 200), // left quarter, full height
        _frame(width: 100, height: 200),
        nativeRotationDegrees: 0,
        needsMirrorCompensation: true,
      );

      // Original x-range [0.0, 0.25] mirrors to [0.75, 1.0].
      expect(result!.left, closeTo(0.75, 1e-9));
      expect(result.right, closeTo(1.0, 1e-9));
    });

    test('degenerate (zero-area) rect returns null', () {
      final result = normalizer.normalizeFaceRect(
        const Rect.fromLTWH(10, 10, 0, 0),
        _frame(),
        nativeRotationDegrees: 0,
        needsMirrorCompensation: false,
      );
      expect(result, isNull);
    });
  });
}
