import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imageflow/features/realtime/data/services/realtime_scene_gate.dart';

/// Locks the scene gate: a flat/blank luminance plane is "not interesting"
/// (detection skipped), a varied one is. This is the guard that stops both the
/// preview slideshow and the false-positive detections on empty scenes.
void main() {
  final gate = RealtimeSceneGate(minStdDev: 12.0);

  Uint8List flat(int value, {int length = 4096}) =>
      Uint8List.fromList(List<int>.filled(length, value));

  // A 1px checkerboard (period 2). The gate's odd stride must still see both
  // phases and report high variance — a power-of-two stride would lock to one
  // phase and wrongly read zero.
  Uint8List checkerboard({int length = 4096}) =>
      Uint8List.fromList(List<int>.generate(length, (i) => i.isEven ? 0 : 255));

  Uint8List gradient({int length = 4096}) =>
      Uint8List.fromList(List<int>.generate(length, (i) => i % 256));

  test('a perfectly flat plane is not interesting (blank wall/desk)', () {
    expect(gate.isInteresting(flat(0)), isFalse);
    expect(gate.isInteresting(flat(128)), isFalse);
    expect(gate.isInteresting(flat(255)), isFalse);
  });

  test('near-flat plane (tiny noise) is still not interesting', () {
    // Values within a couple of levels of each other → stddev well under 12.
    final almostFlat = Uint8List.fromList(
      List<int>.generate(4096, (i) => 128 + (i % 3)),
    );
    expect(gate.isInteresting(almostFlat), isFalse);
  });

  test('high-contrast checkerboard is interesting', () {
    expect(gate.isInteresting(checkerboard()), isTrue);
  });

  test('gradient (real scene variation) is interesting', () {
    expect(gate.isInteresting(gradient()), isTrue);
  });

  test('empty plane fails open (never gate out a frame we cannot judge)', () {
    expect(gate.isInteresting(Uint8List(0)), isTrue);
  });

  test('threshold is honored: a lower minStdDev lets more frames through', () {
    final lenient = RealtimeSceneGate(minStdDev: 0.5);
    final slightlyVaried = Uint8List.fromList(
      List<int>.generate(4096, (i) => 128 + (i % 5)),
    );
    expect(lenient.isInteresting(slightlyVaried), isTrue);
    // The default gate rejects the same slightly-varied frame.
    expect(gate.isInteresting(slightlyVaried), isFalse);
  });
}
