import 'dart:collection';

/// A simple size-bounded LRU (least-recently-used) cache.
///
/// Reads and writes mark a key as most-recently-used; once the entry count
/// exceeds [maxEntries], the least-recently-used keys are evicted. Not
/// thread/isolate-safe — intended for single-isolate in-memory caching.
class LruCache<K, V> {
  LruCache({required this.maxEntries}) : assert(maxEntries > 0);

  final int maxEntries;
  final _entries = <K, V>{};
  final _order = Queue<K>();

  int get length => _entries.length;

  bool containsKey(K key) => _entries.containsKey(key);

  V? read(K key) {
    final value = _entries[key];
    if (value == null) return null;
    _touch(key);
    return value;
  }

  void write(K key, V value) {
    _entries[key] = value;
    _touch(key);
    _trim();
  }

  void remove(K key) {
    _entries.remove(key);
    _order.remove(key);
  }

  void clear() {
    _entries.clear();
    _order.clear();
  }

  void _touch(K key) {
    _order.remove(key);
    _order.addLast(key);
  }

  void _trim() {
    while (_order.length > maxEntries) {
      final oldest = _order.removeFirst();
      _entries.remove(oldest);
    }
  }
}
