import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/context_theme_extensions.dart';
import '../../../../core/widgets/design_system/app_cached_image.dart';

class HistoryThumbnail extends StatelessWidget {
  const HistoryThumbnail({super.key, this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    if (path == null) return _placeholder(context, Icons.image_outlined);

    return ClipRRect(
      borderRadius: BorderRadius.circular(context.tokens.radiusSm),
      child: SizedBox(
        width: 60,
        height: 60,
        child: AppCachedImage(
          imagePath: path!,
          fit: BoxFit.cover,
          cacheWidth: 120,
          cacheHeight: 120,
          errorBuilder: (_, _, _) =>
              _placeholder(context, Icons.broken_image_outlined),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context, IconData icon) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: context.colors.surfaceContainer,
        borderRadius: BorderRadius.circular(context.tokens.radiusSm),
      ),
      child: Icon(icon, color: context.colors.onSurface.withValues(alpha: 0.3)),
    );
  }
}
