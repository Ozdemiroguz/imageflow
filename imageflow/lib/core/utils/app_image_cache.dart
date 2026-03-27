import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/widgets.dart';

/// Lightweight in-memory provider cache for local image files.
///
/// Flutter already caches decoded images globally, but this keeps provider
/// instances stable across rebuilds and gives us explicit eviction points.
abstract final class AppImageCache {
  static const _defaultMaxProviderEntries = 220;
  static int _maxProviderEntries = _defaultMaxProviderEntries;

  static final LinkedHashMap<String, ImageProvider<Object>> _providerLru =
      LinkedHashMap<String, ImageProvider<Object>>();

  static ImageProvider<Object> file(
    String path, {
    int? cacheWidth,
    int? cacheHeight,
    double scale = 1.0,
  }) {
    final normalizedPath = File(path.trim()).absolute.path;
    final key = _buildKey(
      normalizedPath,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      scale: scale,
    );

    final cached = _providerLru.remove(key);
    if (cached != null) {
      _providerLru[key] = cached;
      return cached;
    }

    final baseProvider = FileImage(File(normalizedPath), scale: scale);
    final provider = ResizeImage.resizeIfNeeded(
      cacheWidth,
      cacheHeight,
      baseProvider,
    );

    _providerLru[key] = provider;
    _trimLru();
    return provider;
  }

  static Future<void> evictFile(String path) async {
    final normalizedPath = File(path.trim()).absolute.path;
    final prefix = 'file:$normalizedPath|';
    final matchingKeys = _providerLru.keys
        .where((key) => key.startsWith(prefix))
        .toList(growable: false);

    final providers = <ImageProvider<Object>>[];
    for (final key in matchingKeys) {
      final provider = _providerLru.remove(key);
      if (provider != null) {
        providers.add(provider);
      }
    }

    for (final provider in providers) {
      await provider.evict();
    }
  }

  static Future<void> evictAll() async {
    final providers = _providerLru.values.toList(growable: false);
    _providerLru.clear();

    for (final provider in providers) {
      await provider.evict();
    }
  }

  static int get providerCount => _providerLru.length;
  static int get maxProviderEntries => _maxProviderEntries;

  static void setMaxProviderEntries(int value) {
    _maxProviderEntries = _clampInt(value, 24, 512);
    _trimLru();
  }

  static void _trimLru() {
    while (_providerLru.length > _maxProviderEntries) {
      final oldestKey = _providerLru.keys.first;
      final removed = _providerLru.remove(oldestKey);
      if (removed != null) {
        unawaited(removed.evict());
      }
    }
  }

  static String _buildKey(
    String path, {
    required int? cacheWidth,
    required int? cacheHeight,
    required double scale,
  }) {
    return 'file:$path|w:${cacheWidth ?? 0}|h:${cacheHeight ?? 0}|s:$scale';
  }

  static int _clampInt(int value, int min, int max) {
    return value < min ? min : (value > max ? max : value);
  }
}
