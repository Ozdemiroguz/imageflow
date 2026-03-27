import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../theme/context_theme_extensions.dart';
import '../design_system/app_shimmer.dart';
import '../design_system/app_shimmer_style.dart';

enum PreviewLoadingSkeletonType { face, document }

class PreviewLoadingSkeleton extends StatelessWidget {
  const PreviewLoadingSkeleton({
    super.key,
    required this.message,
    this.type = PreviewLoadingSkeletonType.face,
  });

  final String message;
  final PreviewLoadingSkeletonType type;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final previewHeight = (constraints.maxHeight * 0.42).clamp(
          180.0,
          300.0,
        );

        return Padding(
          padding: EdgeInsets.all(tokens.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppShimmer(
                  style: AppShimmerStyle.normal,
                  child: switch (type) {
                    PreviewLoadingSkeletonType.face => _faceSkeleton(
                      context: context,
                      previewHeight: previewHeight,
                    ),
                    PreviewLoadingSkeletonType.document => _documentSkeleton(
                      context: context,
                      previewHeight: previewHeight,
                    ),
                  },
                ),
              ),
              SizedBox(height: tokens.spacingMd),
              Text(
                message,
                style: context.text.labelLarge?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _faceSkeleton({
    required BuildContext context,
    required double previewHeight,
  }) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _box(context, height: previewHeight, borderRadius: tokens.radiusMd),
        SizedBox(height: tokens.spacingMd),
        Row(
          children: [
            Expanded(
              child: _box(context, height: 74, borderRadius: tokens.radiusSm),
            ),
            SizedBox(width: tokens.spacingSm),
            Expanded(
              child: _box(context, height: 74, borderRadius: tokens.radiusSm),
            ),
          ],
        ),
        SizedBox(height: tokens.spacingMd),
        _box(context, height: 86, borderRadius: tokens.radiusMd),
      ],
    );
  }

  Widget _documentSkeleton({
    required BuildContext context,
    required double previewHeight,
  }) {
    final tokens = context.tokens;
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            children: [
              _box(
                context,
                height: double.infinity,
                borderRadius: tokens.radiusMd,
                child: Padding(
                  padding: EdgeInsets.all(tokens.spacingLg),
                  child: Column(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.center,
                          child: Container(
                            constraints: BoxConstraints(
                              maxHeight: previewHeight,
                              maxWidth: previewHeight * 0.76,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(
                                tokens.radiusSm,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: tokens.spacingSm),
                      _box(
                        context,
                        height: 10,
                        borderRadius: tokens.radiusSm,
                        width: 96,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: tokens.spacingMd,
                bottom: tokens.spacingMd,
                child: _box(
                  context,
                  height: 94,
                  borderRadius: tokens.radiusSm,
                  width: 72,
                  child: Padding(
                    padding: EdgeInsets.all(tokens.spacingXs),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _box(
                          context,
                          height: 8,
                          borderRadius: tokens.radiusSm,
                          width: 38,
                        ),
                        const Spacer(),
                        _box(
                          context,
                          height: 58,
                          borderRadius: tokens.radiusSm,
                          width: double.infinity,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.spacingLg),
        Row(
          children: [
            Expanded(
              child: _box(context, height: 44, borderRadius: tokens.radiusSm),
            ),
            SizedBox(width: tokens.spacingSm),
            Expanded(
              child: _box(context, height: 44, borderRadius: tokens.radiusSm),
            ),
            SizedBox(width: tokens.spacingSm),
            Expanded(
              child: _box(context, height: 44, borderRadius: tokens.radiusSm),
            ),
          ],
        ),
        SizedBox(height: tokens.spacingMd),
        _box(context, height: 68, borderRadius: tokens.radiusMd),
        SizedBox(height: tokens.spacingMd),
        _box(context, height: 48, borderRadius: tokens.radiusMd),
      ],
    );
  }

  Widget _box(
    BuildContext context, {
    required double height,
    required double borderRadius,
    double width = double.infinity,
    Widget? child,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.skeletonBlockColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: SizedBox(width: width, height: height, child: child),
    );
  }
}
