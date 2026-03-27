import 'package:flutter/material.dart';

import '../../theme/context_theme_extensions.dart';
import 'app_shimmer_style.dart';

class AppShimmer extends StatefulWidget {
  const AppShimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1650),
    this.style = AppShimmerStyle.subtle,
    this.enabled = true,
  });

  final Widget child;
  final Duration duration;
  final AppShimmerStyle style;
  final bool enabled;

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void didUpdateWidget(covariant AppShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
      if (_controller.isAnimating) {
        _controller
          ..reset()
          ..repeat();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled ||
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false)) {
      return widget.child;
    }

    final (baseAlpha, highlightAlpha) = switch (widget.style) {
      AppShimmerStyle.subtle => (0.92, 0.9),
      AppShimmerStyle.normal => (1.0, 1.0),
    };
    final base = context.skeletonShimmerBaseColor.withValues(alpha: baseAlpha);
    final highlight = context.skeletonShimmerHighlightColor.withValues(
      alpha: highlightAlpha,
    );

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        final beginX = -1.05 + (2.1 * t);
        final endX = beginX + 0.78;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment(beginX, 0),
              end: Alignment(endX, 0),
              colors: [base, highlight, base],
              stops: const [0.24, 0.5, 0.76],
            ).createShader(rect);
          },
          child: child!,
        );
      },
    );
  }
}
