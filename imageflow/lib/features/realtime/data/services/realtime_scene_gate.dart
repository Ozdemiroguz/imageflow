import 'dart:math' as math;
import 'dart:typed_data';

/// Cheap "is there anything worth analysing?" check for a camera frame.
///
/// When the camera points at a blank, flat surface — a desk, a wall, the
/// ceiling — there is nothing to detect, yet running face/OCR/edge/object ML on
/// every such frame both wastes CPU (dropping the preview to a slideshow) and
/// invents false positives (e.g. "6 faces" on desk grain). This gate samples a
/// handful of luminance (Y) pixels and reports whether the scene has enough
/// variation to be worth the ML pass. It is O(sampleCount), not O(pixels), so
/// it costs effectively nothing per frame.
///
/// Data layer, framework-free.
class RealtimeSceneGate {
  RealtimeSceneGate({
    this.minStdDev = 12.0,
    this.sampleCount = 256,
  });

  /// Minimum luminance standard deviation for a frame to be "interesting".
  /// A flat surface sits near 0; a scene with objects/faces/text is well above.
  /// 12 (on the 0-255 scale) is a conservative floor that clears blank walls
  /// and desks without gating real content.
  final double minStdDev;

  /// How many Y pixels to sample. A few hundred is plenty for a stable stddev
  /// estimate and stays negligible against the frame budget.
  final int sampleCount;

  /// Returns true if [yPlane] (the luminance plane, one byte per pixel) has
  /// enough variation to be worth running detection on. An empty/degenerate
  /// plane returns true (fail open — never gate out a frame we can't judge).
  bool isInteresting(Uint8List yPlane) {
    final length = yPlane.length;
    if (length == 0) return true;

    // Make the stride odd so it can't stay locked to one phase of a periodic
    // pattern (e.g. a checkerboard aligned to a power-of-two stride), which
    // would read a falsely-uniform sample and gate out a busy scene.
    var step = length > sampleCount ? length ~/ sampleCount : 1;
    if (step.isEven) step += 1;

    var count = 0;
    var sum = 0.0;
    var sumSq = 0.0;
    for (var i = 0; i < length; i += step) {
      final v = yPlane[i].toDouble();
      sum += v;
      sumSq += v * v;
      count++;
    }
    if (count == 0) return true;

    final mean = sum / count;
    final variance = (sumSq / count) - (mean * mean);
    // Guard tiny negatives from floating-point error.
    final stdDev = variance <= 0 ? 0.0 : math.sqrt(variance);
    return stdDev >= minStdDev;
  }
}
