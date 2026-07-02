import 'package:flutter_test/flutter_test.dart';
import 'package:imageflow/core/utils/camera_lifecycle_guard.dart';

void main() {
  group('busy lock', () {
    test('begin succeeds when free and blocks a second begin', () {
      final guard = CameraLifecycleGuard();
      expect(guard.isBusy, isFalse);
      expect(guard.begin(), isTrue);
      expect(guard.isBusy, isTrue);
      expect(guard.begin(), isFalse, reason: 'already busy');
    });

    test('end releases the lock', () {
      final guard = CameraLifecycleGuard();
      guard.begin();
      guard.end();
      expect(guard.isBusy, isFalse);
      expect(guard.begin(), isTrue);
    });
  });

  group('generation guard (enabled)', () {
    test('nextGeneration bumps; the latest is current, older ones are stale',
        () {
      final guard = CameraLifecycleGuard();
      final g1 = guard.nextGeneration(enabled: true);
      final g2 = guard.nextGeneration(enabled: true);

      expect(g2, greaterThan(g1));
      expect(guard.isCurrent(g2, enabled: true), isTrue);
      expect(
        guard.isCurrent(g1, enabled: true),
        isFalse,
        reason: 'a newer generation started, so g1 is stale',
      );
    });

    test('invalidate makes the current generation stale', () {
      final guard = CameraLifecycleGuard();
      final g = guard.nextGeneration(enabled: true);
      expect(guard.isCurrent(g, enabled: true), isTrue);

      guard.invalidate(enabled: true);
      expect(guard.isCurrent(g, enabled: true), isFalse);
    });
  });

  group('generation guard (disabled = feature flag off)', () {
    test('nextGeneration does not bump and everything reads as current', () {
      final guard = CameraLifecycleGuard();
      final g1 = guard.nextGeneration(enabled: false);
      final g2 = guard.nextGeneration(enabled: false);

      expect(g1, g2, reason: 'no bump when disabled');
      // With the guard disabled, any generation is treated as current so no
      // async result is ever dropped as "stale".
      expect(guard.isCurrent(g1, enabled: false), isTrue);
      expect(guard.isCurrent(-999, enabled: false), isTrue);
    });

    test('invalidate is a no-op when disabled', () {
      final guard = CameraLifecycleGuard();
      final g = guard.nextGeneration(enabled: true);
      guard.invalidate(enabled: false);
      expect(guard.isCurrent(g, enabled: true), isTrue);
    });
  });
}
