import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../theme/context_theme_extensions.dart';

class FacePreviewItemsView extends StatelessWidget {
  const FacePreviewItemsView({
    super.key,
    required this.items,
    required this.emptyIcon,
    this.tileWidth = 54,
    this.tileHeight = 72,
  });

  final List<Uint8List> items;
  final IconData emptyIcon;
  final double tileWidth;
  final double? tileHeight;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Icon(
          emptyIcon,
          size: 22,
          color: context.colors.onSurface.withValues(alpha: 0.56),
        ),
      );
    }

    final tokens = context.tokens;
    final cacheWidth = tileWidth.round();
    final cacheHeight = tileHeight?.round();

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: items.length,
      separatorBuilder: (_, _) => SizedBox(width: tokens.spacingXs),
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          child: Container(
            width: tileWidth,
            height: tileHeight,
            color: Colors.black.withValues(alpha: 0.18),
            child: Image.memory(
              items[index],
              fit: BoxFit.contain,
              gaplessPlayback: true,
              cacheWidth: cacheWidth,
              cacheHeight: cacheHeight,
            ),
          ),
        );
      },
    );
  }
}
