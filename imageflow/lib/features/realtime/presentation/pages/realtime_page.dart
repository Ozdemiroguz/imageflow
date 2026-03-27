import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/routes/app_route_observer.dart';
import '../../../../core/theme/app_tokens.dart';
import '../controllers/realtime_camera_controller.dart';
import '../widgets/realtime_page_camera_error_view.dart';
import '../widgets/realtime_page_camera_preview.dart';
import '../widgets/realtime_page_capture_bar.dart';

class RealtimePage extends StatefulWidget {
  const RealtimePage({super.key});

  @override
  State<RealtimePage> createState() => _RealtimePageState();
}

class _RealtimePageState extends State<RealtimePage> with RouteAware {
  late final RealtimeCameraController _controller;
  ModalRoute<dynamic>? _subscribedRoute;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<RealtimeCameraController>();
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
            return RealtimeCameraErrorView(
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
            Expanded(
              flex: 3,
              child: RealtimeCameraPreview(controller: _controller),
            ),
            Expanded(
              flex: 1,
              child: RealtimeCaptureBar(controller: _controller),
            ),
          ],
        );
      }),
    );
  }
}
