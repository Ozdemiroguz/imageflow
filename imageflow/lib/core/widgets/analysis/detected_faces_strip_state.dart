part of 'detected_faces_strip.dart';

class _DetectedFacesStripState extends State<DetectedFacesStrip> {
  static const _logTag = 'DetectedFacesStrip';

  late Future<List<Uint8List>> _thumbnailsFuture;
  late final FaceThumbnailCacheService _thumbnailCacheService;

  @override
  void initState() {
    super.initState();
    _thumbnailCacheService = Get.find<FaceThumbnailCacheService>();
    Log.debug(
      'initState. imagePath=${widget.imagePath} rects=${widget.faceRects.length}',
      tag: _logTag,
    );
    _thumbnailsFuture = _loadThumbnailsAfterFirstFrame();
  }

  @override
  void didUpdateWidget(covariant DetectedFacesStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath ||
        !_sameFaceRects(oldWidget.faceRects, widget.faceRects) ||
        !_sameFaceContours(oldWidget.faceContours, widget.faceContours) ||
        oldWidget.maxItems != widget.maxItems) {
      Log.debug(
        'didUpdateWidget -> reload. '
        'oldPath=${oldWidget.imagePath} newPath=${widget.imagePath} '
        'oldRects=${oldWidget.faceRects.length} newRects=${widget.faceRects.length}',
        tag: _logTag,
      );
      _thumbnailsFuture = _loadThumbnails();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.faceRects.isEmpty) return const SizedBox.shrink();

    final tokens = context.tokens;
    final scheme = context.colors;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(tokens.spacingSm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(tokens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: tokens.spacingXs,
        children: [
          Text(
            '${widget.title} (${widget.faceRects.length})',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(
            height: 74,
            child: FutureBuilder<List<Uint8List>>(
              future: _thumbnailsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _LoadingShimmer(maxItems: widget.maxItems);
                }

                final items = snapshot.data ?? const <Uint8List>[];
                if (items.isEmpty) {
                  return Text(
                    'Face area could not be generated',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.62),
                    ),
                  );
                }

                return FacePreviewItemsView(
                  items: items,
                  emptyIcon: Icons.face_retouching_natural_outlined,
                  tileWidth: _LoadingShimmer._tileWidth,
                  tileHeight: _LoadingShimmer._tileHeight,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Uint8List>> _loadThumbnails() async {
    final totalWatch = Stopwatch()..start();
    final inputs = <_FaceThumbnailInput>[];
    for (var i = 0; i < widget.faceRects.length; i++) {
      if (inputs.length >= widget.maxItems) break;
      inputs.add(
        _FaceThumbnailInput(
          rect: widget.faceRects[i],
          contour: i < widget.faceContours.length
              ? widget.faceContours[i]
              : const <({int x, int y})>[],
        ),
      );
    }
    if (inputs.isEmpty) {
      Log.warning(
        'No thumbnail inputs. rects=${widget.faceRects.length}',
        tag: _logTag,
      );
      return const <Uint8List>[];
    }

    final first = inputs.first.rect;
    Log.debug(
      'Start thumbnail build. rects=${inputs.length} '
      'firstRect=(${first.left},${first.top},${first.width},${first.height}) '
      'path=${widget.imagePath} fallback=${widget.fallbackImagePath}',
      tag: _logTag,
    );

    final cacheKey = _thumbnailCacheKey(inputs);
    final cached = _thumbnailCacheService.read(cacheKey);
    if (cached != null) {
      Log.debug(
        'Cache hit. items=${cached.length} path=${widget.imagePath}',
        tag: _logTag,
      );
      totalWatch.stop();
      Log.debug(
        'Cache return. count=${cached.length} total=${totalWatch.elapsedMilliseconds}ms',
        tag: _logTag,
      );
      return cached;
    }

    final primary = await _runBuildWithIsolateFallback(
      widget.imagePath,
      inputs,
      phase: 'primary',
    );
    if (primary.isNotEmpty) {
      _putThumbnailCache(cacheKey, primary);
      totalWatch.stop();
      Log.debug(
        'Primary return. count=${primary.length} total=${totalWatch.elapsedMilliseconds}ms',
        tag: _logTag,
      );
      return primary;
    }

    final primaryRectOnly = await _runBuildWithIsolateFallback(
      widget.imagePath,
      _stripContours(inputs),
      phase: 'primary-rect-only',
    );
    if (primaryRectOnly.isNotEmpty) {
      _putThumbnailCache(cacheKey, primaryRectOnly);
      totalWatch.stop();
      Log.debug(
        'Primary rect-only return. count=${primaryRectOnly.length} total=${totalWatch.elapsedMilliseconds}ms',
        tag: _logTag,
      );
      return primaryRectOnly;
    }

    final fallback = widget.fallbackImagePath;
    if (fallback == null || fallback == widget.imagePath) {
      Log.warning(
        'Primary failed and fallback path missing/same. path=${widget.imagePath}',
        tag: _logTag,
      );
      return const <Uint8List>[];
    }

    final fallbackResult = await _runBuildWithIsolateFallback(
      fallback,
      inputs,
      phase: 'fallback',
    );
    if (fallbackResult.isNotEmpty) {
      _putThumbnailCache(cacheKey, fallbackResult);
      totalWatch.stop();
      Log.debug(
        'Fallback return. count=${fallbackResult.length} total=${totalWatch.elapsedMilliseconds}ms',
        tag: _logTag,
      );
      return fallbackResult;
    }

    final fallbackRectOnly = await _runBuildWithIsolateFallback(
      fallback,
      _stripContours(inputs),
      phase: 'fallback-rect-only',
    );
    if (fallbackRectOnly.isNotEmpty) {
      _putThumbnailCache(cacheKey, fallbackRectOnly);
      totalWatch.stop();
      Log.debug(
        'Fallback rect-only return. count=${fallbackRectOnly.length} total=${totalWatch.elapsedMilliseconds}ms',
        tag: _logTag,
      );
      return fallbackRectOnly;
    }

    Log.warning(
      'No thumbnail generated for any strategy. '
      'rects=${inputs.length} primary=${widget.imagePath} fallback=$fallback',
      tag: _logTag,
    );
    totalWatch.stop();
    Log.debug(
      'No-result return. total=${totalWatch.elapsedMilliseconds}ms',
      tag: _logTag,
    );
    return const <Uint8List>[];
  }

  Future<List<Uint8List>> _loadThumbnailsAfterFirstFrame() async {
    final watch = Stopwatch()..start();
    await SchedulerBinding.instance.endOfFrame;
    if (!mounted) return const <Uint8List>[];
    Log.debug(
      'First frame reached. wait=${watch.elapsedMilliseconds}ms',
      tag: _logTag,
    );
    final items = await _loadThumbnails();
    watch.stop();
    Log.debug(
      'First frame load completed. total=${watch.elapsedMilliseconds}ms items=${items.length}',
      tag: _logTag,
    );
    return items;
  }

  Future<List<Uint8List>> _runBuildWithIsolateFallback(
    String imagePath,
    List<_FaceThumbnailInput> inputs, {
    required String phase,
  }) async {
    final watch = Stopwatch()..start();
    try {
      final result = await Isolate.run(
        () => _buildFaceThumbnails(imagePath, inputs),
      );
      Log.debug(
        '[$phase] isolate result=${result.length} inputs=${inputs.length} '
        'path=$imagePath took=${watch.elapsedMilliseconds}ms',
        tag: _logTag,
      );
      return result;
    } catch (error, stackTrace) {
      Log.warning(
        '[$phase] isolate failed; trying same build on main isolate.',
        tag: _logTag,
      );
      Log.error(
        '[$phase] isolate error',
        error: error,
        stackTrace: stackTrace,
        tag: _logTag,
      );
    }

    try {
      final result = _buildFaceThumbnails(imagePath, inputs);
      Log.debug(
        '[$phase] main-isolate fallback result=${result.length} '
        'inputs=${inputs.length} path=$imagePath '
        'took=${watch.elapsedMilliseconds}ms',
        tag: _logTag,
      );
      return result;
    } catch (error, stackTrace) {
      Log.error(
        '[$phase] main-isolate fallback error',
        error: error,
        stackTrace: stackTrace,
        tag: _logTag,
      );
      return const <Uint8List>[];
    }
  }

  String _thumbnailCacheKey(List<_FaceThumbnailInput> inputs) {
    final buffer = StringBuffer()
      ..write(widget.imagePath)
      ..write('|')
      ..write(widget.fallbackImagePath ?? '')
      ..write('|')
      ..write(widget.maxItems)
      ..write('|');

    for (final input in inputs) {
      final rect = input.rect;
      buffer
        ..write(rect.left)
        ..write(',')
        ..write(rect.top)
        ..write(',')
        ..write(rect.width)
        ..write(',')
        ..write(rect.height)
        ..write(';');

      for (final point in input.contour) {
        buffer
          ..write(point.x)
          ..write(':')
          ..write(point.y)
          ..write(',');
      }
      buffer.write('|');
    }

    return buffer.toString();
  }

  void _putThumbnailCache(String key, List<Uint8List> value) {
    _thumbnailCacheService.write(key, value);
  }

  List<_FaceThumbnailInput> _stripContours(List<_FaceThumbnailInput> inputs) {
    return inputs
        .map(
          (input) => _FaceThumbnailInput(rect: input.rect, contour: const []),
        )
        .toList(growable: false);
  }

  bool _sameFaceRects(
    List<({int left, int top, int width, int height})> a,
    List<({int left, int top, int width, int height})> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].left != b[i].left ||
          a[i].top != b[i].top ||
          a[i].width != b[i].width ||
          a[i].height != b[i].height) {
        return false;
      }
    }
    return true;
  }

  bool _sameFaceContours(
    List<List<({int x, int y})>> a,
    List<List<({int x, int y})>> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final contourA = a[i];
      final contourB = b[i];
      if (contourA.length != contourB.length) return false;
      for (var j = 0; j < contourA.length; j++) {
        if (contourA[j].x != contourB[j].x || contourA[j].y != contourB[j].y) {
          return false;
        }
      }
    }
    return true;
  }
}
