import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/error/failure_ui_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/routes/app_route_observer.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/design_system/app_primary_button.dart';
import '../controllers/camera_capture_controller.dart';

part 'camera_capture_page_preview.dart';
part 'camera_capture_page_capture_bar.dart';
part 'camera_capture_page_error_view.dart';

class CameraCapturePage extends StatefulWidget {
  const CameraCapturePage({super.key});

  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<CameraCapturePage> with RouteAware {
  late final CameraCaptureController _controller;
  ModalRoute<dynamic>? _subscribedRoute;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<CameraCaptureController>();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is ModalRoute<dynamic> && route != _subscribedRoute) {
      if (_subscribedRoute != null) {
        appRouteObserver.unsubscribe(this);
      }
      appRouteObserver.subscribe(this, route);
      _subscribedRoute = route;
    }
  }

  @override
  void dispose() {
    if (_subscribedRoute != null) {
      appRouteObserver.unsubscribe(this);
    }
    super.dispose();
  }

  @override
  void didPushNext() {
    unawaited(_controller.pauseForRoute());
  }

  @override
  void didPopNext() {
    unawaited(_controller.resumeFromRoute());
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Camera'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: Get.back),
        actions: [
          Obx(
            () => IconButton(
              onPressed: _controller.isInitialized.value
                  ? _controller.toggleFlashMode
                  : null,
              tooltip: _flashTooltip(_controller.flashMode.value),
              icon: Icon(_flashIcon(_controller.flashMode.value)),
            ),
          ),
          Obx(() {
            if (!_controller.canSwitchCamera.value) {
              return const SizedBox.shrink();
            }
            if (_controller.isSwitchingCamera.value) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: tokens.spacingLg),
                child: const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            return IconButton(
              icon: const Icon(Icons.cameraswitch_outlined),
              onPressed: _controller.isInitialized.value
                  ? _controller.switchCamera
                  : null,
              tooltip: 'Switch Camera',
            );
          }),
        ],
      ),
      body: Obx(() {
        if (!_controller.isInitialized.value) {
          final f = _controller.failure.value;
          if (f != null) {
            return _CameraErrorView(
              failure: f,
              onRetry: _controller.retryInit,
              onOpenSettings: f is PermissionFailure
                  ? _controller.openSystemSettings
                  : null,
            );
          }
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        return Column(
          children: [
            Expanded(child: _CameraPreview(controller: _controller)),
            _CaptureBar(controller: _controller),
          ],
        );
      }),
    );
  }

  IconData _flashIcon(FlashMode mode) {
    return switch (mode) {
      FlashMode.auto => Icons.flash_auto_outlined,
      FlashMode.always => Icons.flash_on_outlined,
      FlashMode.torch => Icons.flashlight_on_outlined,
      _ => Icons.flash_off_outlined,
    };
  }

  String _flashTooltip(FlashMode mode) {
    return switch (mode) {
      FlashMode.auto => 'Flash Auto',
      FlashMode.always => 'Flash On',
      FlashMode.torch => 'Torch',
      _ => 'Flash Off',
    };
  }
}
