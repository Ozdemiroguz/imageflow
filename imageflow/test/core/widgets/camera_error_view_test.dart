import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imageflow/core/error/failures.dart';
import 'package:imageflow/core/theme/app_theme.dart';
import 'package:imageflow/core/widgets/camera_error_view.dart';

void main() {
  Widget host({
    required Failure failure,
    VoidCallback? onOpenSettings,
    VoidCallback? onRetry,
  }) {
    return MaterialApp(
      theme: AppTheme.dark, // provides the AppTokens theme extension
      home: Scaffold(
        body: CameraErrorView(
          failure: failure,
          onRetry: onRetry ?? () {},
          onOpenSettings: onOpenSettings,
        ),
      ),
    );
  }

  testWidgets(
    'permission failure shows the no-photography icon + Open Settings',
    (tester) async {
      var settingsTapped = false;
      await tester.pumpWidget(
        host(
          failure: const PermissionFailure('Camera access required'),
          onOpenSettings: () => settingsTapped = true,
        ),
      );

      expect(find.byIcon(Icons.no_photography_outlined), findsOneWidget);
      expect(find.byIcon(Icons.videocam_off_outlined), findsNothing);
      expect(find.text('Open Settings'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget); // permission is retryable

      await tester.tap(find.text('Open Settings'));
      expect(settingsTapped, isTrue);
    },
  );

  testWidgets('generic camera failure shows the videocam-off icon, no settings', (
    tester,
  ) async {
    await tester.pumpWidget(host(failure: const CameraFailure('Camera broke')));

    expect(find.byIcon(Icons.videocam_off_outlined), findsOneWidget);
    expect(find.byIcon(Icons.no_photography_outlined), findsNothing);
    // No onOpenSettings callback + not a permission failure → no Settings button.
    expect(find.text('Open Settings'), findsNothing);
  });

  testWidgets('Retry button invokes the retry callback', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      host(failure: const CameraFailure('boom'), onRetry: () => retried = true),
    );

    // CameraFailure is retryable → Retry is shown.
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });
}
