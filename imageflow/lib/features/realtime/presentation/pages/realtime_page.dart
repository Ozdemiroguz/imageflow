import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/routes/app_route_observer.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/camera_error_view.dart';
import '../controllers/realtime_camera_controller.dart';
import '../widgets/realtime_mode_toggle_bar.dart';
import '../widgets/realtime_page_camera_preview.dart';
import '../widgets/realtime_page_capture_bar.dart';
import '../widgets/realtime_scan_speed_panel.dart';

class RealtimePage extends StatefulWidget {
  const RealtimePage({super.key});

  @override
  State<RealtimePage> createState() => _RealtimePageState();
}

class _RealtimePageState extends State<RealtimePage> with RouteAware {
  late final RealtimeCameraController _controller;
  ModalRoute<dynamic>? _subscribedRoute;

  /// Ephemeral UI state: whether the scan-priority panel is expanded. Kept local
  /// to the page (not the controller) because it's purely presentational — the
  /// detector budget lives on the controller regardless of this flag.
  bool _showScanPanel = false;

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
            return CameraErrorView(
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
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RealtimeCameraPreview(controller: _controller),
                  ),
                  Positioned(
                    top: 0,
                    left: 12,
                    right: 12,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: RealtimeModeToggleBar(controller: _controller),
                      ),
                    ),
                  ),
                  // Scan-priority: a toggle button (top-right, under the mode
                  // bar) that reveals the per-detector speed panel at the bottom
                  // of the preview. Collapsed by default so it never covers the
                  // live view unless the user opens it.
                  Positioned(
                    top: 0,
                    right: 12,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 52),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _ScanSpeedToggleButton(
                              active: _showScanPanel,
                              onTap: () => setState(
                                () => _showScanPanel = !_showScanPanel,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Obx(
                              () => _AutoCaptureToggleButton(
                                active: _controller.autoCaptureEnabled.value,
                                onTap: _controller.toggleAutoCapture,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SizeTransition(
                          sizeFactor: anim,
                          child: child,
                        ),
                      ),
                      child: _showScanPanel
                          ? RealtimeScanSpeedPanel(
                              key: const ValueKey('scan-speed-panel'),
                              controller: _controller,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
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

/// The pill button that shows/hides the scan-priority panel. Mirrors the mode
/// bar's chip styling; glows when the panel is open.
class _ScanSpeedToggleButton extends StatelessWidget {
  const _ScanSpeedToggleButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = active ? Colors.white : Colors.white.withValues(alpha: 0.6);
    final bg = active
        ? Colors.white.withValues(alpha: 0.22)
        : Colors.black.withValues(alpha: 0.45);
    final border = active
        ? Colors.white.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.15);

    return Semantics(
      button: true,
      toggled: active,
      label: 'Scan priority',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border, width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.speed_rounded, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                'Speed',
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

/// Toggles auto-capture: when on, a still is captured automatically once the
/// live document holds steady. Active state glows in the document accent.
class _AutoCaptureToggleButton extends StatelessWidget {
  const _AutoCaptureToggleButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.tokens.realtimeDocumentStroke;
    final fg = active ? accent : Colors.white.withValues(alpha: 0.6);
    final bg = active
        ? accent.withValues(alpha: 0.18)
        : Colors.black.withValues(alpha: 0.45);
    final border = active
        ? accent.withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.15);

    return Semantics(
      button: true,
      toggled: active,
      label: 'Auto capture',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border, width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.motion_photos_auto_outlined, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                'Auto',
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
