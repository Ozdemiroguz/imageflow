import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_tokens.dart';
import '../controllers/realtime_camera_controller.dart';
import '../models/realtime_scan_budget.dart';

/// A per-detector "scan priority" panel over the realtime preview.
///
/// Each enabled detector gets a slider that sets its share (weight) of the
/// device scan budget. Raising one detector's slider speeds it up and slows the
/// others proportionally — the combined scan rate never exceeds the budget
/// ceiling, so the device can't be overloaded no matter how the sliders are
/// set. A disabled detector's row is dimmed and inert (toggle it back on in the
/// mode bar). The footer shows the live combined rate against the ceiling.
class RealtimeScanSpeedPanel extends StatelessWidget {
  const RealtimeScanSpeedPanel({required this.controller, super.key});

  final RealtimeCameraController controller;

  // The weight slider range. The budget's proportions only depend on the ratio
  // of weights, so any positive band works; 1..6 gives a usable spread of
  // priorities without a detector ever hitting zero share.
  static const double _minWeight = 1;
  static const double _maxWeight = 6;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.speed_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 7),
              Text(
                'Scan priority',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Obx(() {
            final modes = controller.detectionModes.value;
            final weights = controller.scanWeights.value;
            final intervals = controller.derivedIntervals.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SpeedRow(
                  label: 'Document',
                  accent: tokens.realtimeDocumentStroke,
                  enabled: modes.document,
                  weight: weights[ScanDetector.document] ?? _minWeight,
                  interval: intervals[ScanDetector.document],
                  onChanged: (w) => controller.updateScanWeight(
                    ScanDetector.document,
                    w,
                  ),
                  min: _minWeight,
                  max: _maxWeight,
                ),
                _SpeedRow(
                  label: 'Face',
                  accent: tokens.realtimeFaceStroke,
                  enabled: modes.face,
                  weight: weights[ScanDetector.face] ?? _minWeight,
                  interval: intervals[ScanDetector.face],
                  onChanged: (w) => controller.updateScanWeight(
                    ScanDetector.face,
                    w,
                  ),
                  min: _minWeight,
                  max: _maxWeight,
                ),
                _SpeedRow(
                  label: 'Objects',
                  accent: tokens.realtimeObjectStroke,
                  enabled: modes.object,
                  weight: weights[ScanDetector.object] ?? _minWeight,
                  interval: intervals[ScanDetector.object],
                  onChanged: (w) => controller.updateScanWeight(
                    ScanDetector.object,
                    w,
                  ),
                  min: _minWeight,
                  max: _maxWeight,
                ),
                const SizedBox(height: 6),
                _TotalFooter(
                  intervals: intervals,
                  budget: controller.scanBudgetCeiling,
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _SpeedRow extends StatelessWidget {
  const _SpeedRow({
    required this.label,
    required this.accent,
    required this.enabled,
    required this.weight,
    required this.interval,
    required this.onChanged,
    required this.min,
    required this.max,
  });

  final String label;
  final Color accent;
  final bool enabled;
  final double weight;
  final Duration? interval;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;

  @override
  Widget build(BuildContext context) {
    final fg = enabled
        ? Colors.white.withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.35);
    final rate = interval == null || !enabled
        ? 'off'
        : '${(1000 / interval!.inMilliseconds).toStringAsFixed(1)}/s';

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: enabled ? accent : Colors.white24,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                activeTrackColor: accent,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.16),
                thumbColor: enabled ? accent : Colors.white38,
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 7,
                ),
              ),
              child: Slider(
                value: weight.clamp(min, max),
                min: min,
                max: max,
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ),
          SizedBox(
            width: 42,
            child: Text(
              rate,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalFooter extends StatelessWidget {
  const _TotalFooter({required this.intervals, required this.budget});

  final Map<ScanDetector, Duration> intervals;
  final double budget;

  @override
  Widget build(BuildContext context) {
    final total = intervals.values.fold<double>(
      0,
      (sum, d) => sum + 1000.0 / d.inMilliseconds,
    );
    final fraction = budget <= 0 ? 0.0 : (total / budget).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 4,
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(
              Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Total ${total.toStringAsFixed(1)} / ${budget.toStringAsFixed(0)} scans/sec',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
