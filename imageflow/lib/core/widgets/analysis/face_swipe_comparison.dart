import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../theme/context_theme_extensions.dart';
import '../design_system/app_cached_image.dart';

part 'face_swipe_comparison_image_layer.dart';
part 'face_swipe_comparison_reveal_clipper.dart';

class FaceSwipeComparison extends StatefulWidget {
  const FaceSwipeComparison({
    super.key,
    required this.originalPath,
    required this.processedPath,
  });

  final String originalPath;
  final String processedPath;

  @override
  State<FaceSwipeComparison> createState() => _FaceSwipeComparisonState();
}

class _FaceSwipeComparisonState extends State<FaceSwipeComparison> {
  static const _minSplit = 0.0;
  static const _maxSplit = 1.0;
  final ValueNotifier<double> _split = ValueNotifier<double>(0.52);

  @override
  void dispose() {
    _split.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comparison',
          style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        SizedBox(height: tokens.spacingXs),
        Row(
          children: [
            Text(
              'Original',
              style: context.text.labelSmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const Spacer(),
            Text(
              'Processed',
              style: context.text.labelSmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        SizedBox(height: tokens.spacingSm),
        ValueListenableBuilder<double>(
          valueListenable: _split,
          builder: (context, split, _) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radiusLg),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final panelHeight = _panelHeight(width);
                  final splitX = width * split;
                  final dividerLeft = (splitX - 1.2).clamp(0.0, width - 2.4);
                  final handleLeft = (splitX - 18).clamp(0.0, width - 36.0);
                  // Fixed decode width matches the precacheImage(cacheWidth: 1200)
                  // call in HistoryDetailController — same key → cache hit, no re-decode.
                  const decodeWidth = 1200;

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) =>
                        _updateSplit(details.localPosition.dx / width),
                    onHorizontalDragUpdate: (details) =>
                        _updateSplit(_split.value + (details.delta.dx / width)),
                    child: SizedBox(
                      width: width,
                      height: panelHeight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _ImageLayer(
                            path: widget.originalPath,
                            cacheWidth: decodeWidth,
                          ),
                          ClipRect(
                            clipper: _RevealClipper(splitX),
                            child: _ImageLayer(
                              path: widget.processedPath,
                              cacheWidth: decodeWidth,
                            ),
                          ),
                          Positioned(
                            left: dividerLeft,
                            top: 0,
                            bottom: 0,
                            child: Container(
                              width: 2.4,
                              color: colors.primary.withValues(alpha: 0.9),
                            ),
                          ),
                          Positioned(
                            left: handleLeft,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors.shadow.withValues(
                                        alpha: 0.25,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.compare_arrows,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  double _panelHeight(double width) {
    return (width * 1.1).clamp(220.0, 520.0);
  }

  void _updateSplit(double next) {
    final clamped = next.clamp(_minSplit, _maxSplit);
    if (_split.value == clamped) return;
    _split.value = clamped;
  }
}
