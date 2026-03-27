import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/context_theme_extensions.dart';
import '../../../../core/widgets/design_system/app_cached_image.dart';

class ImagePreview extends StatelessWidget {
  const ImagePreview({super.key, required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(context.tokens.radiusLg),
      child: AppCachedImage(
        imagePath: imagePath,
        fit: BoxFit.contain,
        cacheWidth: 600,
        errorBuilder: (_, _, _) => Center(
          child: Icon(
            Icons.broken_image_outlined,
            size: 64,
            color: context.colors.onSurface.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}
