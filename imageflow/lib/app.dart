import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'core/constants/app_constants.dart';
import 'core/routes/app_route_observer.dart';
import 'core/routes/app_pages.dart';
import 'core/theme/app_theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      initialRoute: AppPages.initial,
      getPages: AppPages.pages,
      navigatorObservers: [appRouteObserver],
      defaultTransition: Transition.fadeIn,
      transitionDuration: AppConstants.pageTransitionDuration,
      builder: (context, child) {
        return MediaQuery.withClampedTextScaling(
          minScaleFactor: AppConstants.minTextScaleFactor,
          maxScaleFactor: AppConstants.maxTextScaleFactor,
          child: child!,
        );
      },
    );
  }
}
