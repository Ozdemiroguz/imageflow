import 'package:flutter/material.dart';

import '../../theme/context_theme_extensions.dart';
import '../design_system/app_cached_image.dart';

class FullscreenImageView extends StatelessWidget {
  const FullscreenImageView({
    super.key,
    required this.imagePath,
    required this.label,
  });

  final String imagePath;
  final String label;

  static void show(
    BuildContext context, {
    required String imagePath,
    required String label,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => FullscreenImageView(imagePath: imagePath, label: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(label),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: AppCachedImage(
            imagePath: imagePath,
            fit: BoxFit.contain,
            showLoading: false,
            errorBuilder: (_, _, _) => Icon(
              Icons.broken_image_outlined,
              size: 64,
              color: context.colors.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }
}
