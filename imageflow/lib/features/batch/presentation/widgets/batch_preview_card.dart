import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/context_theme_extensions.dart';
import '../../../../core/widgets/analysis/fullscreen_image_view.dart';
import '../../../../core/widgets/design_system/app_cached_image.dart';

class BatchPreviewCard extends StatelessWidget {
  const BatchPreviewCard({super.key, required this.label, required this.path});

  final String label;
  final String path;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.text.labelSmall?.copyWith(
            color: colors.onSurface.withValues(alpha: 0.72),
          ),
        ),
        SizedBox(height: tokens.spacingXs),
        AspectRatio(
          aspectRatio: 4 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radiusSm),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => FullscreenImageView.show(
                  context,
                  imagePath: path,
                  label: label,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surfaceContainer,
                        border: Border.all(
                          color: colors.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      child: AppCachedImage(
                        imagePath: path,
                        fit: BoxFit.cover,
                        cacheWidth: 600,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(
                              child: Icon(Icons.broken_image_outlined),
                            ),
                      ),
                    ),
                    Positioned(
                      top: tokens.spacingXs,
                      right: tokens.spacingXs,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(tokens.radiusSm),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(tokens.spacingXs),
                          child: const Icon(Icons.zoom_in_outlined, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
