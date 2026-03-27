import 'package:get/get.dart';

import '../../features/batch/presentation/bindings/batch_binding.dart';
import '../../features/batch/presentation/pages/batch_processing_page.dart';
import '../../features/capture/presentation/bindings/camera_capture_binding.dart';
import '../../features/capture/presentation/bindings/capture_binding.dart';
import '../../features/capture/presentation/pages/camera_capture_page.dart';
import '../../features/history/presentation/bindings/history_detail_binding.dart';
import '../../features/history/presentation/bindings/history_binding.dart';
import '../../features/history/presentation/pages/history_detail_page.dart';
import '../../features/history/presentation/pages/history_page.dart';
import '../../features/processing/presentation/bindings/processing_binding.dart';
import '../../features/processing/presentation/pages/processing_page.dart';
import '../../features/realtime/presentation/bindings/realtime_binding.dart';
import '../../features/realtime/presentation/pages/realtime_page.dart';
import '../../features/result/presentation/bindings/result_binding.dart';
import '../../features/result/presentation/pages/result_page.dart';
import 'app_routes.dart';

class AppPages {
  static const initial = AppRoutes.home;

  static final pages = <GetPage<dynamic>>[
    GetPage<dynamic>(
      name: AppRoutes.home,
      page: () => const HistoryPage(),
      bindings: [CaptureBinding(), HistoryBinding()],
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage<dynamic>(
      name: AppRoutes.capture,
      page: () => const CameraCapturePage(),
      binding: CameraCaptureBinding(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 220),
    ),
    GetPage<dynamic>(
      name: AppRoutes.batch,
      page: () => const BatchProcessingPage(),
      binding: BatchBinding(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 260),
    ),
    GetPage<dynamic>(
      name: AppRoutes.realtime,
      page: () => const RealtimePage(),
      binding: RealtimeBinding(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 220),
    ),
    GetPage<dynamic>(
      name: AppRoutes.processing,
      page: () => const ProcessingPage(),
      binding: ProcessingBinding(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage<dynamic>(
      name: AppRoutes.result,
      page: () => const ResultPage(),
      binding: ResultBinding(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage<dynamic>(
      name: AppRoutes.historyDetail,
      page: () => const HistoryDetailPage(),
      binding: HistoryDetailBinding(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 260),
    ),
  ];
}
