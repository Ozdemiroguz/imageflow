import 'package:flutter/material.dart';

import '../../theme/context_theme_extensions.dart';
import '../../utils/app_image_cache.dart';
import '../design_system/app_shimmer.dart';

part 'app_cached_image_placeholders.dart';

class AppCachedImage extends StatefulWidget {
  const AppCachedImage({
    super.key,
    required this.imagePath,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.cacheWidth,
    this.cacheHeight,
    this.filterQuality = FilterQuality.low,
    this.errorBuilder,
    this.placeholder,
    this.showLoading = true,
    this.fadeDuration = const Duration(milliseconds: 140),
  });

  final String imagePath;
  final BoxFit fit;
  final Alignment alignment;
  final int? cacheWidth;
  final int? cacheHeight;
  final FilterQuality filterQuality;
  final ImageErrorWidgetBuilder? errorBuilder;
  final Widget? placeholder;
  final bool showLoading;
  final Duration fadeDuration;

  @override
  State<AppCachedImage> createState() => _AppCachedImageState();
}

class _AppCachedImageState extends State<AppCachedImage> {
  ImageProvider<Object>? _provider;
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  final ValueNotifier<bool> _isImageReady = ValueNotifier<bool>(false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveProvider(force: false);
  }

  @override
  void didUpdateWidget(covariant AppCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sourceChanged =
        oldWidget.imagePath != widget.imagePath ||
        oldWidget.cacheWidth != widget.cacheWidth ||
        oldWidget.cacheHeight != widget.cacheHeight;
    if (sourceChanged) {
      _resolveProvider(force: true);
      return;
    }
    if (oldWidget.showLoading != widget.showLoading && !widget.showLoading) {
      _isImageReady.value = true;
    }
  }

  @override
  void dispose() {
    _detachImageListener();
    _isImageReady.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _resolveProvider(force: false);
    final provider = _provider!;

    return ValueListenableBuilder<bool>(
      valueListenable: _isImageReady,
      builder: (context, isImageReady, _) {
        final image = AnimatedOpacity(
          opacity: isImageReady ? 1 : 0,
          duration: widget.fadeDuration,
          curve: Curves.easeOut,
          child: Image(
            image: provider,
            fit: widget.fit,
            alignment: widget.alignment,
            filterQuality: widget.filterQuality,
            errorBuilder:
                widget.errorBuilder ?? (_, _, _) => const _DefaultError(),
          ),
        );

        if (!widget.showLoading) {
          return image;
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            AnimatedOpacity(
              opacity: isImageReady ? 0 : 1,
              duration: widget.fadeDuration,
              curve: Curves.easeOut,
              child: widget.placeholder ?? const _DefaultPlaceholder(),
            ),
            image,
          ],
        );
      },
    );
  }

  void _resolveProvider({required bool force}) {
    final provider = AppImageCache.file(
      widget.imagePath,
      cacheWidth: widget.cacheWidth,
      cacheHeight: widget.cacheHeight,
    );

    if (!force && identical(provider, _provider)) {
      return;
    }

    _provider = provider;
    _detachImageListener();
    if (_isImageReady.value && widget.showLoading) {
      _isImageReady.value = false;
    }
    if (!widget.showLoading) {
      _isImageReady.value = true;
    }

    final stream = provider.resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener(
      (info, syncCall) {
        if (!mounted || _isImageReady.value) return;
        _isImageReady.value = true;
      },
      onError: (error, stackTrace) {
        if (!mounted || _isImageReady.value) return;
        _isImageReady.value = true;
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
