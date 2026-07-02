import 'dart:async';

import 'package:flutter/widgets.dart';

/// Coordinates route/app-lifecycle pause & resume for any camera-backed screen.
///
/// Shared by the capture and realtime flows: it pauses the camera when the
/// route is covered or the app goes inactive/background, and resumes it when
/// the route returns and the app is resumed. This is a plain class, not a
/// GetxService — callers wire its [pauseForRoute]/[resumeFromRoute]/
/// [handleAppLifecycleState] hooks and pass pause/resume callbacks.
class CameraRouteLifecycleController {
  CameraRouteLifecycleController({
    required Future<void> Function() onPauseForLifecycle,
    required Future<void> Function() onResumeCameraSession,
    this.enableRouteAwareLifecycle = true,
    this.enableInactiveDebounce = true,
    this.inactiveDisposeDelay = const Duration(milliseconds: 350),
    AppLifecycleState? initialAppLifecycleState,
  }) : _onPauseForLifecycle = onPauseForLifecycle,
       _onResumeCameraSession = onResumeCameraSession,
       _appLifecycleState =
           initialAppLifecycleState ??
           WidgetsBinding.instance.lifecycleState ??
           AppLifecycleState.resumed;

  final Future<void> Function() _onPauseForLifecycle;
  final Future<void> Function() _onResumeCameraSession;
  final bool enableRouteAwareLifecycle;
  final bool enableInactiveDebounce;
  final Duration inactiveDisposeDelay;

  AppLifecycleState _appLifecycleState;
  var _isPausedByRoute = false;
  Timer? _inactiveDisposeDebounce;

  AppLifecycleState get appLifecycleState => _appLifecycleState;
  bool get isPausedByRoute => _isPausedByRoute;

  Future<void> pauseForRoute() async {
    if (!enableRouteAwareLifecycle || _isPausedByRoute) return;
    _isPausedByRoute = true;
    _cancelInactiveDisposeDebounce();
    await _onPauseForLifecycle();
  }

  Future<void> resumeFromRoute() async {
    if (!enableRouteAwareLifecycle || !_isPausedByRoute) return;
    _isPausedByRoute = false;
    if (_appLifecycleState != AppLifecycleState.resumed) return;
    await _onResumeCameraSession();
  }

  Future<void> handleAppLifecycleState(AppLifecycleState state) async {
    _appLifecycleState = state;

    switch (state) {
      case AppLifecycleState.resumed:
        _cancelInactiveDisposeDebounce();
        if (_isPausedByRoute && enableRouteAwareLifecycle) {
          return;
        }
        await _onResumeCameraSession();
        return;
      case AppLifecycleState.inactive:
        if (enableInactiveDebounce) {
          _scheduleInactiveDisposeDebounce();
        } else {
          await _onPauseForLifecycle();
        }
        return;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _cancelInactiveDisposeDebounce();
        await _onPauseForLifecycle();
        return;
    }
  }

  void dispose() {
    _cancelInactiveDisposeDebounce();
  }

  void _scheduleInactiveDisposeDebounce() {
    _cancelInactiveDisposeDebounce();
    _inactiveDisposeDebounce = Timer(inactiveDisposeDelay, () {
      unawaited(_onInactiveDisposeDebounceFired());
    });
  }

  Future<void> _onInactiveDisposeDebounceFired() async {
    _inactiveDisposeDebounce = null;
    if (_isPausedByRoute && enableRouteAwareLifecycle) {
      return;
    }
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      return;
    }
    await _onPauseForLifecycle();
  }

  void _cancelInactiveDisposeDebounce() {
    _inactiveDisposeDebounce?.cancel();
    _inactiveDisposeDebounce = null;
  }
}
