import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';

part 'gradient_fab_quick_action_fab.dart';

class GradientFab extends StatelessWidget {
  const GradientFab({super.key, required this.onCapturePressed});

  final VoidCallback onCapturePressed;

  static Future<void> _openRealtime() async {
    await Get.toNamed(AppRoutes.realtime);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: context.tokens.spacingMd,
      children: [
        const _QuickActionFab(
          heroTag: 'history_realtime_fab',
          onPressed: _openRealtime,
          gradient: LinearGradient(
            colors: [AppColors.greatGreyOwl, AppColors.screechOwl],
          ),
          icon: Icons.center_focus_strong_rounded,
          tooltip: 'Realtime',
          hasBonusBadge: true,
        ),
        _QuickActionFab(
          heroTag: 'history_capture_fab',
          onPressed: onCapturePressed,
          gradient: AppColors.primaryGradient,
          icon: Icons.add,
          tooltip: 'Capture',
        ),
      ],
    );
  }
}
