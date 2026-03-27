import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import 'permission_warning.dart';

class CameraDeniedWarning extends StatelessWidget {
  const CameraDeniedWarning({required this.cameraDenied, super.key});

  final RxBool cameraDenied;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!cameraDenied.value) {
        return const SizedBox.shrink();
      }
      return const PermissionWarning(
        message: 'Camera access denied.',
        onOpenSettings: openAppSettings,
      );
    });
  }
}
