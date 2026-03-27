import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../theme/context_theme_extensions.dart';
import '../design_system/app_cached_image.dart';
import 'fullscreen_image_view.dart';

class ComparisonImage extends StatelessWidget {
  const ComparisonImage({
    super.key,
    required this.label,
    required this.imagePath,
  });

  final String label;
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: tokens.spacingXs,
      children: [
        Text(
          label,
          style: context.text.labelSmall?.copyWith(
            color: context.colors.onSurface.withValues(alpha: 0.5),
          ),
        ),
        GestureDetector(
          onTap: () => FullscreenImageView.show(
            context,
            imagePath: imagePath,
            label: label,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radiusMd),
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 3 / 4,
                  child: ColoredBox(
                    color: Colors.transparent,
                    child: AppCachedImage(
                      imagePath: imagePath,
                      fit: BoxFit.contain,
                      cacheWidth: 400,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.broken_image_outlined,
                        color: context.colors.onSurface.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: tokens.spacingXs,
                  right: tokens.spacingXs,
                  child: Container(
                    padding: EdgeInsets.all(tokens.spacingSm),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.zoom_in,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
