import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../theme/context_theme_extensions.dart';
import '../../utils/app_image_cache.dart';
import '../design_system/app_cached_image.dart';
import 'fullscreen_image_view.dart';

part 'face_compact_previews_row_tile.dart';

class FaceCompactPreviewsRow extends StatelessWidget {
  const FaceCompactPreviewsRow({
    super.key,
    required this.originalPath,
    required this.processedPath,
  });

  final String originalPath;
  final String processedPath;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Preview',
          style: context.text.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.colors.onSurface.withValues(alpha: 0.7),
          ),
        ),
        SizedBox(height: tokens.spacingSm),
        Row(
          children: [
            Flexible(
              child: _CompactPreviewTile(
                label: 'Original',
                imagePath: originalPath,
              ),
            ),
            SizedBox(width: tokens.spacingSm),
            Flexible(
              child: _CompactPreviewTile(
                label: 'Processed',
                imagePath: processedPath,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
