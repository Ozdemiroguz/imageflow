abstract class AppConstants {
  static const appName = 'ImageFlow';
  static const thumbnailSize = 200;
  static const thumbnailDisplaySize = 60.0;
  static const maxTextScaleFactor = 1.5;
  static const minTextScaleFactor = 1.0;
  static const pageTransitionDuration = Duration(milliseconds: 300);

  /// [pageTransitionDuration] plus a small buffer. Screens defer heavy startup
  /// work (camera bring-up, Hive reads, ML pipelines, PDF raster) by this long
  /// so it never competes with the entrance animation for frames.
  static const routeTransitionSettleDelay = Duration(milliseconds: 350);
  static const enableCaptureRouteAwareLifecycle = true;
  static const enableRealtimeRouteAwareLifecycle = true;
  static const enableCameraInactiveDebounce = true;
  static const enableCameraInitGenerationGuard = true;
}
