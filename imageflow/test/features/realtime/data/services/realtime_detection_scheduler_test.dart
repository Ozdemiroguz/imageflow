import 'package:flutter_test/flutter_test.dart';
import 'package:imageflow/features/realtime/data/services/realtime_detection_scheduler.dart';

void main() {
  // Fixed base time; the scheduler takes `now` as a parameter, so tests control
  // the clock rather than relying on DateTime.now().
  final t0 = DateTime(2026, 1, 1, 12);

  RealtimeDetectionScheduler makeScheduler({
    Duration face = const Duration(milliseconds: 100),
    Duration ocr = const Duration(milliseconds: 100),
    Duration edge = const Duration(milliseconds: 100),
    Duration facePanel = const Duration(milliseconds: 100),
    Duration docPanel = const Duration(milliseconds: 100),
  }) => RealtimeDetectionScheduler(
    faceInterval: face,
    ocrInterval: ocr,
    edgeInterval: edge,
    facePanelInterval: facePanel,
    documentPanelInterval: docPanel,
  );

  group('face detection slot (acquire/release)', () {
    test('first acquire succeeds', () {
      final s = makeScheduler();
      expect(s.tryBeginFaceDetection(t0), isTrue);
    });

    test('cannot re-acquire while busy, even after the interval elapses', () {
      final s = makeScheduler();
      expect(s.tryBeginFaceDetection(t0), isTrue);
      // Busy: a second begin fails regardless of elapsed time.
      expect(
        s.tryBeginFaceDetection(t0.add(const Duration(seconds: 10))),
        isFalse,
      );
    });

    test('after release, still throttled until the interval elapses', () {
      final s = makeScheduler(face: const Duration(milliseconds: 100));
      s.tryBeginFaceDetection(t0);
      s.endFaceDetection();

      // Too soon after the last run.
      expect(
        s.tryBeginFaceDetection(t0.add(const Duration(milliseconds: 50))),
        isFalse,
      );
      // Interval elapsed → allowed again.
      expect(
        s.tryBeginFaceDetection(t0.add(const Duration(milliseconds: 100))),
        isTrue,
      );
    });
  });

  group('edge detection gated on OCR text', () {
    test('edge is blocked until OCR reports text', () {
      final s = makeScheduler();
      // No OCR text yet → edge cannot begin.
      expect(s.tryBeginEdgeDetection(t0), isFalse);

      s.endOcrDetection(hasText: true);
      expect(s.hasOcrText, isTrue);
      expect(s.tryBeginEdgeDetection(t0), isTrue);
    });

    test('OCR reporting no text keeps edge blocked', () {
      final s = makeScheduler();
      s.endOcrDetection(hasText: false);
      expect(s.hasOcrText, isFalse);
      expect(s.tryBeginEdgeDetection(t0), isFalse);
    });
  });

  group('panel throttle slots (no lock/release)', () {
    test('takes a slot, then throttles until the interval elapses', () {
      final s = makeScheduler(facePanel: const Duration(milliseconds: 100));
      expect(s.tryTakeFacePanelSlot(t0), isTrue);
      // Too soon.
      expect(
        s.tryTakeFacePanelSlot(t0.add(const Duration(milliseconds: 40))),
        isFalse,
      );
      // Elapsed.
      expect(
        s.tryTakeFacePanelSlot(t0.add(const Duration(milliseconds: 100))),
        isTrue,
      );
    });

    test('document panel slot is independent from face panel slot', () {
      final s = makeScheduler();
      expect(s.tryTakeFacePanelSlot(t0), isTrue);
      // Taking the face slot must not consume the document slot.
      expect(s.tryTakeDocumentPanelSlot(t0), isTrue);
    });
  });

  group('reset', () {
    test('clears busy flags, timers, and OCR text', () {
      final s = makeScheduler();
      s.tryBeginFaceDetection(t0); // busy + last-run set
      s.endOcrDetection(hasText: true);
      s.tryTakeFacePanelSlot(t0);

      s.reset();

      expect(s.hasOcrText, isFalse);
      // Not busy and no throttle history → immediately acquirable at t0.
      expect(s.tryBeginFaceDetection(t0), isTrue);
      expect(s.tryTakeFacePanelSlot(t0), isTrue);
    });
  });
}
