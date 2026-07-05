import 'realtime_detection_modes.dart';

/// Which detector a budget share belongs to.
///
/// These are the three detectors that actually consume per-frame CPU/GC in the
/// realtime loop. (OCR is intentionally not run in realtime, and the preview
/// panels are a UI-refresh throttle rather than a detector load, so neither
/// takes a budget share — see [RealtimeScanBudget].)
enum ScanDetector { face, document, object }

/// A device-wide "scans per second" budget shared across the enabled realtime
/// detectors, split by per-detector priority weights.
///
/// ## Why a budget instead of fixed intervals
///
/// Each detector (face / document-edge / object) costs CPU and allocates on
/// every pass. With independent fixed intervals, enabling all three at once can
/// push a mid-range device past its frame budget (jank, GC pressure). A single
/// total budget makes the ceiling explicit: no matter which detectors are on or
/// how the user re-prioritizes them, the *sum* of scan rates never exceeds
/// [totalScansPerSecond], so the device can't be overloaded.
///
/// ## How the split works
///
/// The budget is divided among only the **enabled** detectors, in proportion to
/// their [weights]. Disabling a detector frees its share for the others rather
/// than wasting it. Each resulting interval is then clamped to a sane
/// per-detector floor/ceiling (see [minInterval] / [maxInterval]) so a single
/// enabled detector can't be handed an absurdly fast rate (which would just
/// starve the ML pipeline) or an imperceptibly slow one.
///
/// ## Purity
///
/// This class is pure math — no Flutter, no camera, no clock — so the whole
/// budget policy is unit-testable in isolation. [CaptureRealtimeConfig] holds an
/// instance and derives the scheduler's `Duration`s from it, keeping the
/// scheduler itself unchanged.
class RealtimeScanBudget {
  const RealtimeScanBudget({
    required this.totalScansPerSecond,
    this.perWeightScansPerSecond = _defaultPerWeightRate,
    this.weights = _defaultWeights,
    this.minInterval = _defaultMinInterval,
    this.maxInterval = _defaultMaxInterval,
  }) : assert(totalScansPerSecond > 0, 'budget must be positive'),
       assert(perWeightScansPerSecond > 0, 'per-weight rate must be positive');

  /// The hard ceiling: total detector scans per second the device is allowed to
  /// spend across all enabled detectors combined. No matter how high the user
  /// pushes the priority sliders, the combined rate is capped here — this is
  /// what protects the frame budget. Tune per platform from on-device
  /// measurement. It can be set aggressively (headroom for high-end devices)
  /// because the *starting* rate is governed by the weights × [perWeight
  /// ScansPerSecond], not by this ceiling.
  final double totalScansPerSecond;

  /// How many scans/sec one unit of weight buys, before the ceiling caps the
  /// total. This decouples the aggressive [totalScansPerSecond] ceiling from the
  /// starting rate: with the default weights (sum 6) and ~1.5/weight, the
  /// default split lands near a measured-safe ~9/sec, and only when the user
  /// raises a slider does the total climb toward the ceiling. Low-end devices
  /// therefore start safe; high-end devices can be pushed to the ceiling.
  final double perWeightScansPerSecond;

  /// Relative priority of each detector. Higher weight → larger share of the
  /// budget → faster scan rate. Only the weights of *enabled* detectors count.
  final Map<ScanDetector, double> weights;

  /// Per-detector fastest allowed interval (floor). Prevents handing a lone
  /// enabled detector a rate faster than its ML backend can usefully consume
  /// (e.g. ML Kit face throughput), which would burn budget for no gain.
  final Map<ScanDetector, Duration> minInterval;

  /// Per-detector slowest allowed interval (ceiling). Keeps a low-weight
  /// detector from going so slow it looks frozen even when the budget is tight.
  final Map<ScanDetector, Duration> maxInterval;

  // ~1.5 scans/sec per unit of weight. With the default weights (sum 6) all on,
  // the raw total is ~9/sec — the measured jank-safe rate on a mid-range device
  // — comfortably under an aggressive ceiling. Raising a slider spends the
  // remaining headroom up to totalScansPerSecond.
  static const _defaultPerWeightRate = 1.5;

  static const _defaultWeights = <ScanDetector, double>{
    // Document edge detection is the primary realtime capability, so it gets the
    // largest share; face is secondary; objects change slowly and can be looser.
    ScanDetector.document: 3,
    ScanDetector.face: 2,
    ScanDetector.object: 1,
  };

  static const _defaultMinInterval = <ScanDetector, Duration>{
    // ML Kit face / OpenCV edge saturate well before ~120ms; objects even
    // sooner. These floors stop the split from over-spending on one detector.
    ScanDetector.face: Duration(milliseconds: 160),
    ScanDetector.document: Duration(milliseconds: 120),
    ScanDetector.object: Duration(milliseconds: 300),
  };

  static const _defaultMaxInterval = <ScanDetector, Duration>{
    ScanDetector.face: Duration(milliseconds: 900),
    ScanDetector.document: Duration(milliseconds: 800),
    ScanDetector.object: Duration(milliseconds: 1200),
  };

  /// The scan interval for each *enabled* detector at the current weights.
  ///
  /// Each detector's raw rate is `weight * perWeightScansPerSecond`. If the
  /// combined raw rate would exceed [totalScansPerSecond], every detector is
  /// scaled down proportionally so the total sits exactly on the ceiling — this
  /// is the frame-budget guard. Below the ceiling the raw rates stand, so with
  /// modest default weights the total starts safe and only climbs toward the
  /// ceiling as the user raises sliders. Each resulting interval is clamped to
  /// the detector's [minInterval]..[maxInterval]. Returns an empty map when
  /// nothing is enabled.
  Map<ScanDetector, Duration> intervalsFor(RealtimeDetectionModes enabled) {
    final active = <ScanDetector>[
      if (enabled.face) ScanDetector.face,
      if (enabled.document) ScanDetector.document,
      if (enabled.object) ScanDetector.object,
    ];
    if (active.isEmpty) return const {};

    // Raw desired rate per detector: weight buys scans/sec directly.
    final rawRates = <ScanDetector, double>{
      for (final d in active) d: (weights[d] ?? 0) * perWeightScansPerSecond,
    };
    final rawTotal = rawRates.values.fold<double>(0, (s, r) => s + r);

    // All-zero-weight guard: fall back to an even split of the full ceiling so
    // the budget is still spent rather than producing zero rates.
    if (rawTotal <= 0) {
      final even = totalScansPerSecond / active.length;
      return {
        for (final d in active)
          d: _clamp(d, Duration(milliseconds: (1000.0 / even).round())),
      };
    }

    // Cap at the ceiling: if the raw total overshoots, scale every rate down by
    // the same factor so proportions hold and the total lands on the ceiling.
    final scale = rawTotal > totalScansPerSecond
        ? totalScansPerSecond / rawTotal
        : 1.0;

    final result = <ScanDetector, Duration>{};
    for (final d in active) {
      final rate = rawRates[d]! * scale; // > 0, so the division below is safe.
      final ms = (1000.0 / rate).round();
      result[d] = _clamp(d, Duration(milliseconds: ms));
    }
    return result;
  }

  Duration _clamp(ScanDetector d, Duration raw) {
    final lo = minInterval[d];
    final hi = maxInterval[d];
    if (lo != null && raw < lo) return lo;
    if (hi != null && raw > hi) return hi;
    return raw;
  }

  RealtimeScanBudget copyWith({
    double? totalScansPerSecond,
    double? perWeightScansPerSecond,
    Map<ScanDetector, double>? weights,
    Map<ScanDetector, Duration>? minInterval,
    Map<ScanDetector, Duration>? maxInterval,
  }) {
    return RealtimeScanBudget(
      totalScansPerSecond: totalScansPerSecond ?? this.totalScansPerSecond,
      perWeightScansPerSecond:
          perWeightScansPerSecond ?? this.perWeightScansPerSecond,
      weights: weights ?? this.weights,
      minInterval: minInterval ?? this.minInterval,
      maxInterval: maxInterval ?? this.maxInterval,
    );
  }
}
