import 'package:flutter_test/flutter_test.dart';
import 'package:imageflow/features/realtime/presentation/models/realtime_detection_modes.dart';
import 'package:imageflow/features/realtime/presentation/models/realtime_scan_budget.dart';

/// Total scans-per-second implied by a set of intervals.
double _sumRate(Map<ScanDetector, Duration> intervals) => intervals.values
    .fold<double>(0, (sum, d) => sum + 1000.0 / d.inMilliseconds);

void main() {
  // Unclamped budget so the raw split math is observable. per-weight rate 1.0
  // makes the arithmetic easy to reason about (weight == scans/sec below the
  // ceiling). Clamp behaviour is exercised separately.
  const unclamped = RealtimeScanBudget(
    totalScansPerSecond: 100, // high ceiling → raw rates stand, no scaling
    perWeightScansPerSecond: 1,
    weights: {
      ScanDetector.document: 3,
      ScanDetector.face: 2,
      ScanDetector.object: 1,
    },
    minInterval: {},
    maxInterval: {},
  );

  const allOn = RealtimeDetectionModes();

  group('split across enabled detectors', () {
    test('all enabled: every detector gets a share', () {
      final iv = unclamped.intervalsFor(allOn);
      expect(iv.keys, containsAll(ScanDetector.values));
      expect(iv.length, 3);
    });

    test('disabled detectors are absent from the result', () {
      final iv = unclamped.intervalsFor(allOn.copyWith(object: false));
      expect(iv.containsKey(ScanDetector.object), isFalse);
      expect(iv.keys, containsAll([ScanDetector.face, ScanDetector.document]));
    });

    test('nothing enabled → empty map (no divide-by-zero)', () {
      final iv = unclamped.intervalsFor(
        const RealtimeDetectionModes(
          face: false,
          document: false,
          object: false,
        ),
      );
      expect(iv, isEmpty);
    });
  });

  group('below the ceiling: weight buys rate directly', () {
    test('rate equals weight * perWeightScansPerSecond', () {
      final iv = unclamped.intervalsFor(allOn);
      // per-weight 1.0 → document weight 3 == 3 scans/sec == 333ms, etc.
      expect(1000.0 / iv[ScanDetector.document]!.inMilliseconds,
          closeTo(3.0, 0.05));
      expect(
          1000.0 / iv[ScanDetector.face]!.inMilliseconds, closeTo(2.0, 0.05));
      expect(
          1000.0 / iv[ScanDetector.object]!.inMilliseconds, closeTo(1.0, 0.05));
    });

    test('a disabled detector does NOT speed the others up below the ceiling',
        () {
      // Unlike the old ceiling-filling model: below the ceiling each detector's
      // rate is absolute, so turning one off leaves the others unchanged.
      final all = unclamped.intervalsFor(allOn);
      final noObject = unclamped.intervalsFor(allOn.copyWith(object: false));
      expect(
        noObject[ScanDetector.document]!.inMilliseconds,
        all[ScanDetector.document]!.inMilliseconds,
      );
    });

    test('perWeightScansPerSecond scales all rates', () {
      final slow = unclamped.copyWith(perWeightScansPerSecond: 0.5);
      final fast = unclamped.copyWith(perWeightScansPerSecond: 2.0);
      final slowDoc = 1000.0 / slow.intervalsFor(allOn)[ScanDetector.document]!.inMilliseconds;
      final fastDoc = 1000.0 / fast.intervalsFor(allOn)[ScanDetector.document]!.inMilliseconds;
      expect(fastDoc / slowDoc, closeTo(4.0, 0.1));
    });
  });

  group('the ceiling caps the total (frame-budget guard)', () {
    // A low ceiling that the raw rates (sum 6 at per-weight 1.0) overshoot.
    const capped = RealtimeScanBudget(
      totalScansPerSecond: 3,
      perWeightScansPerSecond: 1,
      weights: {
        ScanDetector.document: 3,
        ScanDetector.face: 2,
        ScanDetector.object: 1,
      },
      minInterval: {},
      maxInterval: {},
    );

    test('total never exceeds the ceiling when raw rates overshoot', () {
      final iv = capped.intervalsFor(allOn);
      expect(_sumRate(iv), lessThanOrEqualTo(3 + 0.2));
    });

    test('proportional scaling preserves the weight ratios', () {
      final iv = capped.intervalsFor(allOn);
      final docRate = 1000.0 / iv[ScanDetector.document]!.inMilliseconds;
      final objRate = 1000.0 / iv[ScanDetector.object]!.inMilliseconds;
      // document weight 3, object weight 1 → ~3x even after scaling to ceiling.
      expect(docRate / objRate, closeTo(3.0, 0.2));
    });

    test('above the ceiling, freeing a detector reallocates its share', () {
      // When capped, the two remaining detectors split the full ceiling, so
      // document ends up faster than with all three competing.
      final all = capped.intervalsFor(allOn);
      final noObject = capped.intervalsFor(allOn.copyWith(object: false));
      expect(
        noObject[ScanDetector.document]!.inMilliseconds,
        lessThan(all[ScanDetector.document]!.inMilliseconds),
      );
      expect(_sumRate(noObject), lessThanOrEqualTo(3 + 0.2));
    });
  });

  group('weights set the proportions', () {
    test('higher weight → faster rate (shorter interval)', () {
      final iv = unclamped.intervalsFor(allOn);
      expect(
        iv[ScanDetector.document]!.inMilliseconds,
        lessThan(iv[ScanDetector.face]!.inMilliseconds),
      );
      expect(
        iv[ScanDetector.face]!.inMilliseconds,
        lessThan(iv[ScanDetector.object]!.inMilliseconds),
      );
    });

    test('raising one weight speeds it up', () {
      final boosted = unclamped.copyWith(
        weights: {
          ScanDetector.document: 6,
          ScanDetector.face: 2,
          ScanDetector.object: 1,
        },
      );
      final before = unclamped.intervalsFor(allOn);
      final after = boosted.intervalsFor(allOn);
      expect(
        after[ScanDetector.document]!.inMilliseconds,
        lessThan(before[ScanDetector.document]!.inMilliseconds),
      );
    });

    test('all-zero weights fall back to an even split of the ceiling', () {
      const zero = RealtimeScanBudget(
        totalScansPerSecond: 9,
        weights: {
          ScanDetector.document: 0,
          ScanDetector.face: 0,
          ScanDetector.object: 0,
        },
        minInterval: {},
        maxInterval: {},
      );
      final iv = zero.intervalsFor(allOn);
      final ms = iv.values.map((d) => d.inMilliseconds).toSet();
      expect(ms.length, 1); // even → all equal
      expect(_sumRate(iv), lessThanOrEqualTo(9 + 0.2));
    });
  });

  group('per-detector clamps', () {
    test('a huge per-weight rate is capped by the min-interval floor', () {
      const huge = RealtimeScanBudget(
        totalScansPerSecond: 1000,
        perWeightScansPerSecond: 1000,
        minInterval: {ScanDetector.face: Duration(milliseconds: 160)},
        maxInterval: {},
      );
      final iv = huge.intervalsFor(allOn);
      expect(iv[ScanDetector.face]!.inMilliseconds, greaterThanOrEqualTo(160));
    });

    test('a tiny per-weight rate is capped by the max-interval ceiling', () {
      const tiny = RealtimeScanBudget(
        totalScansPerSecond: 1000,
        perWeightScansPerSecond: 0.001,
        maxInterval: {ScanDetector.document: Duration(milliseconds: 800)},
        minInterval: {},
      );
      final iv = tiny.intervalsFor(allOn);
      expect(iv[ScanDetector.document]!.inMilliseconds, lessThanOrEqualTo(800));
    });

    test('the shipped default budget keeps every detector in a sane band', () {
      const defaults = RealtimeScanBudget(totalScansPerSecond: 14);
      final iv = defaults.intervalsFor(allOn);
      // Default weights + per-weight 1.5 → the measured-safe ~9/sec split.
      expect(_sumRate(iv), closeTo(9.0, 1.0));
      for (final entry in iv.entries) {
        final ms = entry.value.inMilliseconds;
        expect(ms, greaterThanOrEqualTo(100), reason: '${entry.key} too fast');
        expect(ms, lessThanOrEqualTo(1300), reason: '${entry.key} too slow');
      }
    });

    test('default is safe but a maxed slider climbs toward the ceiling', () {
      const defaults = RealtimeScanBudget(totalScansPerSecond: 14);
      final base = _sumRate(defaults.intervalsFor(allOn));
      final pushed = defaults.copyWith(
        weights: {
          ScanDetector.document: 6,
          ScanDetector.face: 6,
          ScanDetector.object: 6,
        },
      );
      final pushedTotal = _sumRate(pushed.intervalsFor(allOn));
      expect(base, lessThan(pushedTotal)); // sliders do climb
      expect(pushedTotal, lessThanOrEqualTo(14 + 0.5)); // but never past ceiling
    });
  });

  test('asserts a positive budget', () {
    expect(
      () => RealtimeScanBudget(totalScansPerSecond: 0),
      throwsA(isA<AssertionError>()),
    );
  });
}
