import '../../../core/utils/perf_trace.dart';
import '../presentation/models/batch_item_status.dart';

class BatchRunMetricsTracker {
  static const _perfTag = 'PerfBatch';

  Stopwatch? _runStopwatch;
  var _processedItems = 0;
  var _successItems = 0;
  var _failedItems = 0;
  var _totalItemMs = 0;
  var _maxItemMs = 0;

  void begin() {
    if (!PerfTrace.isEnabled) return;
    _runStopwatch = Stopwatch()..start();
    _resetRunStats();
  }

  void recordItem({
    required int itemIndex,
    required BatchItemStatus status,
    required int elapsedMs,
  }) {
    if (!PerfTrace.isEnabled || elapsedMs < 0) return;

    _processedItems += 1;
    _totalItemMs += elapsedMs;
    if (elapsedMs > _maxItemMs) {
      _maxItemMs = elapsedMs;
    }

    if (status == BatchItemStatus.success) {
      _successItems += 1;
    } else if (status == BatchItemStatus.failed) {
      _failedItems += 1;
    }

    final details = 'index=$itemIndex status=${status.name}';
    if (elapsedMs >= 1500) {
      PerfTrace.warning(
        'batch.item.total',
        elapsedMs,
        tag: _perfTag,
        details: details,
      );
      return;
    }

    PerfTrace.info(
      'batch.item.total',
      elapsedMs,
      tag: _perfTag,
      details: details,
    );
  }

  void finish({required int pendingCount}) {
    if (!PerfTrace.isEnabled) return;
    final watch = _runStopwatch;
    if (watch == null) return;
    watch.stop();

    final totalMs = watch.elapsedMilliseconds;
    final avgItemMs = _processedItems == 0
        ? 0
        : (_totalItemMs / _processedItems).round();
    final details =
        'processed=$_processedItems'
        ' success=$_successItems'
        ' failed=$_failedItems'
        ' avgItem=${avgItemMs}ms'
        ' maxItem=${_maxItemMs}ms'
        ' pending=$pendingCount';

    if (_failedItems > 0) {
      PerfTrace.warning(
        'batch.run.total',
        totalMs,
        tag: _perfTag,
        details: details,
      );
    } else {
      PerfTrace.info(
        'batch.run.total',
        totalMs,
        tag: _perfTag,
        details: details,
      );
    }

    _runStopwatch = null;
  }

  void _resetRunStats() {
    _processedItems = 0;
    _successItems = 0;
    _failedItems = 0;
    _totalItemMs = 0;
    _maxItemMs = 0;
  }
}
