import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../theme/context_theme_extensions.dart';
import '../design_system/app_cached_image.dart';

class OriginalPreviewCard extends StatelessWidget {
  const OriginalPreviewCard({super.key, required this.imagePath, this.onTap});

  final String imagePath;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(tokens.radiusMd),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(tokens.spacingSm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: tokens.spacingSm,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: tokens.spacingXs,
                  children: [
                    Text(
                      'Original',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Icon(Icons.zoom_in, size: 14, color: Colors.white70),
                  ],
                ),
                SizedBox(
                  width: 84,
                  height: 112,
                  child: AppCachedImage(
                    imagePath: imagePath,
                    fit: BoxFit.contain,
                    cacheWidth: 240,
                    cacheHeight: 320,
                    errorBuilder: (_, _, _) => Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 18,
                        color: colors.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
