import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/context_theme_extensions.dart';
import 'camera_denied_warning.dart';
import 'source_option.dart';

class CaptureDialog extends StatelessWidget {
  const CaptureDialog({
    required this.onPickFromCamera,
    required this.onPickFromGallery,
    required this.onPickBatchFromGallery,
    this.cameraDenied,
    this.showCameraDeniedWarning = true,
    super.key,
  });

  final VoidCallback? onPickFromCamera;
  final VoidCallback? onPickFromGallery;
  final VoidCallback? onPickBatchFromGallery;
  final RxBool? cameraDenied;
  final bool showCameraDeniedWarning;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: tokens.spacingLg,
        vertical: tokens.spacingXl,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusLg),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: tokens.spacingSm,
          children: [
            Text(
              'Choose Source',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            Divider(
              height: tokens.spacingLg,
              color: colors.outlineVariant.withValues(alpha: 0.35),
            ),
            SourceOption(
              icon: Icons.camera_alt_outlined,
              label: 'Camera',
              subtitle: 'Open camera preview',
              onTap: onPickFromCamera ?? () {},
            ),
            if (showCameraDeniedWarning && cameraDenied != null)
              CameraDeniedWarning(cameraDenied: cameraDenied!),
            SourceOption(
              icon: Icons.photo_library_outlined,
              label: 'Gallery',
              subtitle: 'Choose from library',
              onTap: onPickFromGallery ?? () {},
            ),
            SourceOption(
              icon: Icons.collections_outlined,
              label: 'Batch (Gallery)',
              subtitle: 'Select multiple images',
              onTap: onPickBatchFromGallery ?? () {},
              hasBonusBadge: true,
            ),
          ],
        ),
      ),
    );
  }
}
