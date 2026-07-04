import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_tokens.dart';
import '../controllers/realtime_camera_controller.dart';

/// Three independent detector toggles (Face / Document / Object) overlaid at the
/// top of the realtime preview. Each can be turned on or off; any combination
/// runs — all, some, one, or none. An active chip glows in its detector's
/// accent color; an inactive one is dimmed.
class RealtimeModeToggleBar extends StatelessWidget {
  const RealtimeModeToggleBar({required this.controller, super.key});

  final RealtimeCameraController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Obx(() {
      final modes = controller.detectionModes.value;
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ModeChip(
            icon: Icons.face_retouching_natural_outlined,
            label: 'Face',
            active: modes.face,
            activeColor: tokens.realtimeFaceStroke,
            onTap: controller.toggleFaceMode,
          ),
          const SizedBox(width: 8),
          _ModeChip(
            icon: Icons.description_outlined,
            label: 'Document',
            active: modes.document,
            activeColor: tokens.realtimeDocumentStroke,
            onTap: controller.toggleDocumentMode,
          ),
          const SizedBox(width: 8),
          _ModeChip(
            icon: Icons.category_outlined,
            label: 'Objects',
            active: modes.object,
            activeColor: tokens.realtimeObjectStroke,
            onTap: controller.toggleObjectMode,
          ),
        ],
      );
    });
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = active ? activeColor : Colors.white.withValues(alpha: 0.55);
    final bg = active
        ? activeColor.withValues(alpha: 0.18)
        : Colors.black.withValues(alpha: 0.45);
    final border = active
        ? activeColor.withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.15);

    return Semantics(
      button: true,
      toggled: active,
      label: '$label detection',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border, width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
