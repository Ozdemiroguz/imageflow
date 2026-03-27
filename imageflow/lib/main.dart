import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'app.dart';
import 'core/modal/modal_service_factory.dart';
import 'core/services/face_thumbnail_cache_service.dart';
import 'core/services/file_service.dart';
import 'core/services/image_cache_policy_service.dart';
import 'core/services/modal_service.dart';
import 'core/services/pdf_external_open_service.dart';
import 'core/services/pdf_raster/pdf_raster_service.dart';
import 'core/services/permission_service.dart';
import 'core/services/storage_service.dart';
import 'core/utils/log.dart';
import 'features/history/di/history_dependencies.dart';

Future<void> main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = _onFlutterError;
      PlatformDispatcher.instance.onError = _onPlatformError;

      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]);

      await _initServices();
      runApp(const App());
    },
    (error, stackTrace) {
      Log.error('Uncaught zone error', tag: 'App', error: error, stackTrace: stackTrace);
    },
  );
}

Future<void> _initServices() async {
  Log.info('Initializing services...', tag: 'App');

  await Future.wait([
    Get.putAsync<StorageService>(() => StorageService().init()),
    Get.putAsync<FileService>(() => FileService().init()),
    Get.putAsync<ImageCachePolicyService>(
      () => ImageCachePolicyService().init(),
      permanent: true,
    ),
  ]);
  await ensureHistoryStorageReady();

  Get.put<PdfRasterService>(PdfRasterService(), permanent: true);
  Get.put<PdfExternalOpenService>(PdfExternalOpenService(), permanent: true);
  Get.put<FaceThumbnailCacheService>(
    FaceThumbnailCacheService(),
    permanent: true,
  );
  Get.put<PermissionService>(PermissionService(), permanent: true);
  Get.put<ModalService>(ModalServiceFactory.create(), permanent: true);

  Log.info('Services initialized', tag: 'App');
}

void _onFlutterError(FlutterErrorDetails details) {
  FlutterError.presentError(details);
  Log.error(
    'Flutter framework error',
    tag: 'App',
    error: details.exception,
    stackTrace: details.stack ?? StackTrace.current,
  );
}

bool _onPlatformError(Object error, StackTrace stackTrace) {
  Log.error('Uncaught platform error', tag: 'App', error: error, stackTrace: stackTrace);
  return true;
}
