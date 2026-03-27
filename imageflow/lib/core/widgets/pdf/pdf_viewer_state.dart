part of 'pdf_viewer.dart';

class _PdfViewerState extends State<PdfViewer> {
  late PdfViewerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    unawaited(_controller.ensureLoaded());
  }

  @override
  void didUpdateWidget(covariant PdfViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _controller = widget.controller;
      unawaited(_controller.ensureLoaded());
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Column(
      children: [
        Expanded(
          child: Obx(() {
            if (_controller.isLoading.value) {
              return const _PdfViewerLoadingSkeleton();
            }

            final failure = _controller.failure.value;
            if (failure != null) {
              final ui = FailureUiMapper.map(failure);
              return PdfLoadError(
                title: ui.title,
                message: ui.message,
                canRetry: ui.canRetry,
                onRetry: () => _controller.load(forceRefresh: true),
              );
            }

            final pages = List.of(_controller.pages);
            return ColoredBox(
              color: context.colors.surfaceContainerLow,
              child: PageView.builder(
                itemCount: pages.length,
                onPageChanged: (i) {
                  if (_controller.currentPage.value != i) {
                    _controller.currentPage.value = i;
                  }
                },
                itemBuilder: (_, i) => Padding(
                  padding: EdgeInsets.all(tokens.spacingLg),
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Image.memory(
                        pages[i],
                        fit: BoxFit.contain,
                        cacheWidth: 1200,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        Obx(() {
          if (_controller.isLoading.value ||
              _controller.failure.value != null ||
              _controller.totalPages == 0) {
            return const SizedBox.shrink();
          }

          final currentPage = _controller.currentPage.value;
          return Padding(
            padding: EdgeInsets.symmetric(vertical: tokens.spacingSm),
            child: Text(
              '${_controller.pageLabel(currentPage)}  ·  '
              '${currentPage + 1} / ${_controller.totalPages}',
              style: context.text.labelMedium?.copyWith(
                color: context.colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _PdfViewerLoadingSkeleton extends StatelessWidget {
  const _PdfViewerLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;

    return ColoredBox(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: EdgeInsets.all(tokens.spacingLg),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: AppShimmer(
                    style: AppShimmerStyle.normal,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: AspectRatio(
                        aspectRatio: 0.72,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: context.skeletonBlockColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: tokens.spacingSm),
            AppShimmer(
              child: Container(
                width: 118,
                height: 10,
                decoration: BoxDecoration(
                  color: context.skeletonBlockColor,
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
