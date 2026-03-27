import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import 'comparison_image.dart';

class ImageComparison extends StatelessWidget {
  const ImageComparison({
    super.key,
    required this.originalPath,
    required this.processedPath,
  });

  final String originalPath;
  final String processedPath;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Row(
      spacing: tokens.spacingSm,
      children: [
        Expanded(
          child: ComparisonImage(label: 'Original', imagePath: originalPath),
        ),
        Expanded(
          child: ComparisonImage(label: 'Processed', imagePath: processedPath),
        ),
      ],
    );
  }
}
