import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imageflow/core/theme/app_theme.dart';
import 'package:imageflow/core/widgets/analysis/document_info_strip.dart';

void main() {
  Widget host({
    required int extractedTextLength,
    required String? extractedText,
    VoidCallback? onViewExtractedText,
  }) {
    return MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: DocumentInfoStrip(
          fileSize: 2048,
          extractedTextLength: extractedTextLength,
          extractedText: extractedText,
          onViewExtractedText: onViewExtractedText ?? () {},
        ),
      ),
    );
  }

  testWidgets('shows "View Content" and char chip when text is present', (
    tester,
  ) async {
    var viewed = false;
    await tester.pumpWidget(
      host(
        extractedTextLength: 42,
        extractedText: 'some text',
        onViewExtractedText: () => viewed = true,
      ),
    );

    expect(find.text('View Content'), findsOneWidget);
    expect(find.text('42 chars'), findsOneWidget);

    await tester.tap(find.text('View Content'));
    expect(viewed, isTrue);
  });

  testWidgets('hides "View Content" when there is no text', (tester) async {
    await tester.pumpWidget(host(extractedTextLength: 0, extractedText: null));

    expect(find.text('View Content'), findsNothing);
    // No char chip either when length is 0.
    expect(find.textContaining('chars'), findsNothing);
  });

  testWidgets('empty string is treated as no text', (tester) async {
    await tester.pumpWidget(host(extractedTextLength: 0, extractedText: ''));
    expect(find.text('View Content'), findsNothing);
  });
}
