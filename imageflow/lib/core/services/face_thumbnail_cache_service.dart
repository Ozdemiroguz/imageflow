import 'dart:typed_data';

import 'package:get/get.dart';

import '../utils/lru_cache.dart';

/// Shared LRU cache for face preview thumbnails.
///
/// Thin GetxService adapter over [LruCache] that additionally treats an empty
/// thumbnail list as "no value" (never stored, never returned).
class FaceThumbnailCacheService extends GetxService {
  FaceThumbnailCacheService({int maxEntries = 24})
    : _cache = LruCache<String, List<Uint8List>>(maxEntries: maxEntries);

  final LruCache<String, List<Uint8List>> _cache;

  List<Uint8List>? read(String key) {
    final value = _cache.read(key);
    if (value == null || value.isEmpty) return null;
    return value;
  }

  void write(String key, List<Uint8List> value) {
    if (value.isEmpty) return;
    _cache.write(key, value);
  }

  void remove(String key) => _cache.remove(key);

  void clear() => _cache.clear();

  @override
  void onClose() {
    clear();
    super.onClose();
  }
}
