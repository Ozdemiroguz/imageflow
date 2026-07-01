import 'package:flutter_test/flutter_test.dart';
import 'package:imageflow/core/utils/lru_cache.dart';

void main() {
  group('LruCache', () {
    test('reads back what was written', () {
      final cache = LruCache<String, int>(maxEntries: 3);
      cache.write('a', 1);
      expect(cache.read('a'), 1);
      expect(cache.containsKey('a'), isTrue);
      expect(cache.length, 1);
    });

    test('returns null for missing key', () {
      final cache = LruCache<String, int>(maxEntries: 3);
      expect(cache.read('missing'), isNull);
    });

    test('evicts the least-recently-used key when over capacity', () {
      final cache = LruCache<String, int>(maxEntries: 2);
      cache.write('a', 1);
      cache.write('b', 2);
      cache.write('c', 3); // evicts 'a'

      expect(cache.read('a'), isNull);
      expect(cache.read('b'), 2);
      expect(cache.read('c'), 3);
      expect(cache.length, 2);
    });

    test('a read refreshes recency so it survives eviction', () {
      final cache = LruCache<String, int>(maxEntries: 2);
      cache.write('a', 1);
      cache.write('b', 2);
      cache.read('a'); // 'a' now most-recently-used
      cache.write('c', 3); // evicts 'b', not 'a'

      expect(cache.read('a'), 1);
      expect(cache.read('b'), isNull);
      expect(cache.read('c'), 3);
    });

    test('rewriting a key updates value and recency', () {
      final cache = LruCache<String, int>(maxEntries: 2);
      cache.write('a', 1);
      cache.write('b', 2);
      cache.write('a', 10); // update + refresh 'a'
      cache.write('c', 3); // evicts 'b'

      expect(cache.read('a'), 10);
      expect(cache.read('b'), isNull);
      expect(cache.read('c'), 3);
    });

    test('remove and clear drop entries', () {
      final cache = LruCache<String, int>(maxEntries: 3);
      cache.write('a', 1);
      cache.write('b', 2);
      cache.remove('a');
      expect(cache.read('a'), isNull);
      expect(cache.length, 1);

      cache.clear();
      expect(cache.length, 0);
      expect(cache.read('b'), isNull);
    });
  });
}
