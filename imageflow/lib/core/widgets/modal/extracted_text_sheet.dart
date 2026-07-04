import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
import '../../theme/app_tokens.dart';
import '../../theme/context_theme_extensions.dart';

class ExtractedTextSheet extends StatefulWidget {
  const ExtractedTextSheet({
    super.key,
    required this.text,
    this.title = 'Document Content',
    this.contentDelay = AppConstants.routeTransitionSettleDelay,
  });

  final String text;
  final String title;

  /// Laying out a long OCR text in one [SelectableText] is expensive and used
  /// to run synchronously on tap, delaying the sheet's slide-in. The content
  /// is deferred by this long so the animation starts instantly; the header
  /// and a small spinner render in the meantime. Pass [Duration.zero] in tests.
  final Duration contentDelay;

  @override
  State<ExtractedTextSheet> createState() => _ExtractedTextSheetState();
}

class _ExtractedTextSheetState extends State<ExtractedTextSheet> {
  late bool _showContent = widget.contentDelay == Duration.zero;

  @override
  void initState() {
    super.initState();
    if (!_showContent) {
      Future<void>.delayed(widget.contentDelay, () {
        if (mounted) setState(() => _showContent = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (sheetContext, scrollController) {
        final tokens = sheetContext.tokens;

        return Column(
          children: [
            Padding(
              padding: EdgeInsets.all(tokens.spacingLg),
              child: Row(
                children: [
                  Text(
                    widget.title,
                    style: sheetContext.text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _showContent
                  ? SingleChildScrollView(
                      controller: scrollController,
                      padding: EdgeInsets.all(tokens.spacingLg),
                      child: SelectableText(
                        widget.text,
                        style: sheetContext.text.bodyMedium,
                      ),
                    )
                  : const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}
