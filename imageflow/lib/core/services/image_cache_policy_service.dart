import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../utils/app_image_cache.dart';
import '../utils/log.dart';

/// Manages Flutter decoded image cache limits and reacts to memory pressure.
class ImageCachePolicyService extends GetxService with WidgetsBindingObserver {
  static const _tag = 'ImageCachePolicy';

  static const _mb = 1024 * 1024;
  static const _minForegroundBytes = 64 * _mb;
  static const _maxForegroundBytes = 200 * _mb;
  static const _minBackgroundBytes = 28 * _mb;
  static const _maxBackgroundBytes = 72 * _mb;
  static const _screenBytesMultiplier = 14;

  late final int _foregroundMaxBytes;
  late final int _foregroundMaxEntries;
  late final int _backgroundMaxBytes;
  late final int _backgroundMaxEntries;

  Future<ImageCachePolicyService> init() async {
    WidgetsBinding.instance.addObserver(this);
    _computePolicyFromDisplay();
    _applyForegroundPolicy();
    return this;
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _applyForegroundPolicy();
        return;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _applyBackgroundPolicy();
        return;
    }
  }

  @override
  void didHaveMemoryPressure() {
    _purgeAggressive();
  }

  void _computePolicyFromDisplay() {
    final dispatcher = PlatformDispatcher.instance;
    final view = dispatcher.views.isNotEmpty
        ? dispatcher.views.first
        : dispatcher.implicitView;
    final physicalSize = view?.physicalSize ?? const Size(1080, 1920);
    final screenBytes = _clampInt(
      (physicalSize.width * physicalSize.height * 4).round(),
      1,
      1 << 31,
    );

    _foregroundMaxBytes = _clampInt(
      (screenBytes * _screenBytesMultiplier).round(),
      _minForegroundBytes,
      _maxForegroundBytes,
    );
    _foregroundMaxEntries = _estimateEntries(
      targetBytes: _foregroundMaxBytes,
      screenBytes: screenBytes,
      minEntries: 28,
      maxEntries: 120,
    );

    _backgroundMaxBytes = _clampInt(
      _foregroundMaxBytes ~/ 3,
      _minBackgroundBytes,
      _maxBackgroundBytes,
    );
    _backgroundMaxEntries = _clampInt(_foregroundMaxEntries ~/ 2, 12, 56);
  }

  int _estimateEntries({
    required int targetBytes,
    required int screenBytes,
    required int minEntries,
    required int maxEntries,
  }) {
    // Most images are downscaled with cacheWidth/cacheHeight before decode.
    final avgDecodedFrameBytes = _clampInt(
      (screenBytes * 0.55).round(),
      1,
      1 << 31,
    );
    final raw = (targetBytes / avgDecodedFrameBytes).round();
    return _clampInt(raw, minEntries, maxEntries);
  }

  void _applyForegroundPolicy() {
    final cache = PaintingBinding.instance.imageCache;
    cache.maximumSizeBytes = _foregroundMaxBytes;
    cache.maximumSize = _foregroundMaxEntries;
    AppImageCache.setMaxProviderEntries(_foregroundMaxEntries * 2);
    Log.debug(
      'Foreground cache policy applied: '
      'bytes=${_foregroundMaxBytes ~/ _mb}MB '
      'entries=$_foregroundMaxEntries '
      'providerEntries=${AppImageCache.maxProviderEntries}',
      tag: _tag,
    );
  }

  void _applyBackgroundPolicy() {
    final cache = PaintingBinding.instance.imageCache;
    cache.maximumSizeBytes = _backgroundMaxBytes;
    cache.maximumSize = _backgroundMaxEntries;
    cache.clear();
    AppImageCache.setMaxProviderEntries(_backgroundMaxEntries);
    Log.debug(
      'Background cache policy applied: '
      'bytes=${_backgroundMaxBytes ~/ _mb}MB '
      'entries=$_backgroundMaxEntries '
      'providerEntries=${AppImageCache.maxProviderEntries}',
      tag: _tag,
    );
  }

  void _purgeAggressive() {
    final cache = PaintingBinding.instance.imageCache;
    cache.clear();
    cache.clearLiveImages();
    unawaited(AppImageCache.evictAll());
    Log.warning('Memory pressure received: image caches purged.', tag: _tag);
  }

  int _clampInt(int value, int min, int max) {
    return value < min ? min : (value > max ? max : value);
  }
}
