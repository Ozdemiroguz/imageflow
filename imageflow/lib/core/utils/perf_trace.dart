import 'package:flutter/foundation.dart';

import 'log.dart';

/// Lightweight performance logging helper.
///
/// Enable with:
/// `flutter run --dart-define=IMAGEFLOW_PERF_TRACE=true`
abstract final class PerfTrace {
  static const _enabledByEnv = bool.fromEnvironment(
    'IMAGEFLOW_PERF_TRACE',
    defaultValue: false,
  );

  static bool get isEnabled => kDebugMode && _enabledByEnv;

  static Stopwatch? start() {
    if (!isEnabled) return null;
    return Stopwatch()..start();
  }

  static int stopMs(Stopwatch? watch) {
    if (watch == null) return -1;
    watch.stop();
    return watch.elapsedMilliseconds;
  }

  static void info(
    String metric,
    int elapsedMs, {
    String tag = 'Perf',
    String? details,
  }) {
    if (!isEnabled || elapsedMs < 0) return;
    final suffix = details == null || details.isEmpty ? '' : ' $details';
    Log.info('[perf] $metric=${elapsedMs}ms$suffix', tag: tag);
  }

  static void warning(
    String metric,
    int elapsedMs, {
    String tag = 'Perf',
    String? details,
  }) {
    if (!isEnabled || elapsedMs < 0) return;
    final suffix = details == null || details.isEmpty ? '' : ' $details';
    Log.warning('[perf] $metric=${elapsedMs}ms$suffix', tag: tag);
  }
}
