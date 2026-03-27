import 'dart:collection';
import 'dart:typed_data';

import 'package:get/get.dart';

/// Shared LRU cache for face preview thumbnails.
class FaceThumbnailCacheService extends GetxService {
  FaceThumbnailCacheService({this.maxEntries = 24});

  final int maxEntries;
  final _cache = <String, List<Uint8List>>{};
  final _order = Queue<String>();

  List<Uint8List>? read(String key) {
    final value = _cache[key];
    if (value == null || value.isEmpty) return null;
    _touch(key);
    return value;
  }

  void write(String key, List<Uint8List> value) {
    if (value.isEmpty) return;
    _cache[key] = value;
    _touch(key);
    _trim();
  }

  void remove(String key) {
    _cache.remove(key);
    _order.remove(key);
  }

  void clear() {
    _cache.clear();
    _order.clear();
  }

  @override
  void onClose() {
    clear();
    super.onClose();
  }

  void _touch(String key) {
    _order.remove(key);
    _order.addLast(key);
  }

  void _trim() {
    while (_order.length > maxEntries) {
      final oldest = _order.removeFirst();
      _cache.remove(oldest);
    }
  }
}
