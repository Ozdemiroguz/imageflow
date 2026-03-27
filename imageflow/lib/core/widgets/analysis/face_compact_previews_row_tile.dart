part of 'face_compact_previews_row.dart';

class _CompactPreviewTile extends StatefulWidget {
  const _CompactPreviewTile({required this.label, required this.imagePath});

  final String label;
  final String imagePath;

  @override
  State<_CompactPreviewTile> createState() => _CompactPreviewTileState();
}

class _CompactPreviewTileState extends State<_CompactPreviewTile> {
  final ValueNotifier<Size?> _imageSize = ValueNotifier<Size?>(null);
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  static const _tileHeight = 112.0;
  static const _minTileWidth = 70.0;

  @override
  void initState() {
    super.initState();
    _resolveImageSize();
  }

  @override
  void didUpdateWidget(covariant _CompactPreviewTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _resolveImageSize();
    }
  }

  @override
  void dispose() {
    _detachImageListener();
    _imageSize.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;

    return ValueListenableBuilder<Size?>(
      valueListenable: _imageSize,
      builder: (context, imageSize, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = _resolveTileWidth(constraints.maxWidth, imageSize);

            return Align(
              alignment: Alignment.center,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => FullscreenImageView.show(
                  context,
                  imagePath: widget.imagePath,
                  label: widget.label,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(tokens.radiusMd),
                  child: SizedBox(
                    width: width,
                    height: _tileHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AppCachedImage(
                          imagePath: widget.imagePath,
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          cacheWidth: 320,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.broken_image_outlined,
                            size: 18,
                            color: colors.onSurface.withValues(alpha: 0.35),
                          ),
                        ),
                        Positioned(
                          left: tokens.spacingXs,
                          top: tokens.spacingXs,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.44),
                              borderRadius: BorderRadius.circular(
                                tokens.radiusSm,
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: tokens.spacingXs,
                                vertical: tokens.spacingXs / 2,
                              ),
                              child: Text(
                                widget.label,
                                style: context.text.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: tokens.spacingXs,
                          top: tokens.spacingXs,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.44),
                              shape: BoxShape.circle,
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(5),
                              child: Icon(
                                Icons.zoom_in,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  double _resolveTileWidth(double maxWidth, Size? source) {
    if (source == null || source.width <= 0 || source.height <= 0) {
      return maxWidth;
    }
    final aspect = source.width / source.height;
    final naturalWidth = _tileHeight * aspect;
    return naturalWidth.clamp(_minTileWidth, maxWidth);
  }

  void _resolveImageSize() {
    _detachImageListener();
    _imageSize.value = null;

    final provider = AppImageCache.file(widget.imagePath);
    final stream = provider.resolve(const ImageConfiguration());
    final listener = ImageStreamListener(
      (info, _) {
        if (!mounted) return;
        _imageSize.value = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
        _detachImageListener();
      },
      onError: (error, stackTrace) {
        _detachImageListener();
      },
    );

    _imageStream = stream;
    _imageListener = listener;
    stream.addListener(listener);
  }

  void _detachImageListener() {
    final stream = _imageStream;
    final listener = _imageListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _imageStream = null;
    _imageListener = null;
  }
}
