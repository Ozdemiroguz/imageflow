import 'dart:collection';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../error/failures.dart';
import '../../error/result.dart';
import '../../utils/log.dart';
import '../../utils/perf_trace.dart';

part 'pdf_raster_service_rasterizer_typedef.dart';
part 'pdf_raster_service_byte_loader_typedef.dart';
part 'pdf_raster_service_dpi_resolver_typedef.dart';

/// App-wide PDF rasterization service with in-flight dedupe and small LRU cache.
class PdfRasterService extends GetxService {
  PdfRasterService({
    PdfRasterizer? rasterizer,
    PdfByteLoader? byteLoader,
    PdfDpiResolver? dpiResolver,
  }) : _rasterizer = rasterizer ?? _defaultRasterizer,
       _byteLoader = byteLoader ?? _defaultByteLoader,
       _dpiResolver = dpiResolver ?? _defaultDpi;

  static const _tag = 'PdfRasterService';
  static const _perfTag = 'PerfPdf';
  static const _maxCacheEntries = 3;
  static const _nativeChannel = MethodChannel(
    'com.oguzhan.imageflow/pdf_raster',
  );

  final PdfRasterizer _rasterizer;
  final PdfByteLoader _byteLoader;
  final PdfDpiResolver _dpiResolver;

  final _cache = <String, List<Uint8List>>{};
  final _cacheOrder = Queue<String>();
  final _inFlight = <String, Future<Result<List<Uint8List>>>>{};

  Future<Result<List<Uint8List>>> rasterize({
    required String pdfPath,
    bool forceRefresh = false,
  }) async {
    final totalWatch = PerfTrace.start();

    if (!forceRefresh) {
      final cached = _cache[pdfPath];
      if (cached != null) {
        PerfTrace.info(
          'pdf.raster.cache_hit',
          PerfTrace.stopMs(totalWatch),
          tag: _perfTag,
          details: 'pages=${cached.length}',
        );
        return Result.ok(cached);
      }

      final existing = _inFlight[pdfPath];
      if (existing != null) {
        PerfTrace.info(
          'pdf.raster.inflight_hit',
          PerfTrace.stopMs(totalWatch),
          tag: _perfTag,
        );
        return existing;
      }
    }

    var usedNative = false;

    final future = Result.guard<List<Uint8List>>(
      () async {
        if (pdfPath.trim().isEmpty) {
          throw const PdfFailure('PDF path is empty.');
        }

        final file = File(pdfPath);
        // ignore: avoid_slow_async_io
        if (!await file.exists()) {
          throw const FileFailure('PDF file not found.');
        }

        final dpi = _dpiResolver();
        final nativeWatch = PerfTrace.start();
        final nativePages = await _tryNativeRasterize(
          pdfPath: pdfPath,
          dpi: dpi,
        );
        final nativeMs = PerfTrace.stopMs(nativeWatch);

        late final List<Uint8List> pages;
        if (nativePages != null && nativePages.isNotEmpty) {
          usedNative = true;
          Log.info(
            'Using native PDF rasterization (${nativePages.length} page(s)).',
            tag: _tag,
          );
          PerfTrace.info(
            'pdf.raster.native',
            nativeMs,
            tag: _perfTag,
            details: 'pages=${nativePages.length}',
          );
          pages = nativePages;
        } else {
          usedNative = false;
          Log.info('Using custom raster fallback.', tag: _tag);
          final fallbackWatch = PerfTrace.start();
          final bytes = await _byteLoader(pdfPath);
          pages = await _rasterizer(bytes, dpi);
          PerfTrace.info(
            'pdf.raster.fallback',
            PerfTrace.stopMs(fallbackWatch),
            tag: _perfTag,
            details: 'pages=${pages.length}',
          );
        }

        if (pages.isEmpty) {
          throw const PdfFailure('PDF has no renderable pages.');
        }

        return List<Uint8List>.unmodifiable(pages);
      },
      onError: _mapFailure,
      onLog: (e, st) => Log.error(
        'PDF rasterization failed',
        error: e,
        stackTrace: st,
        tag: _tag,
      ),
    );

    _inFlight[pdfPath] = future;
    final result = await future;
    final _ = _inFlight.remove(pdfPath);

    switch (result) {
      case Ok(:final value):
        _putCache(pdfPath, value);
        PerfTrace.info(
          'pdf.raster.total',
          PerfTrace.stopMs(totalWatch),
          tag: _perfTag,
          details: 'status=ok pages=${value.length} source=${usedNative ? 'native' : 'fallback'}',
        );
      case Error():
        PerfTrace.warning(
          'pdf.raster.total',
          PerfTrace.stopMs(totalWatch),
          tag: _perfTag,
          details: 'status=error',
        );
    }

    return result;
  }

  void invalidate(String pdfPath) {
    if (!_cache.containsKey(pdfPath)) return;
    _cache.remove(pdfPath);
    _cacheOrder.remove(pdfPath);
  }

  void clearAll() {
    _cache.clear();
    _cacheOrder.clear();
  }

  Failure _mapFailure(Object error) {
    if (error is Failure) return error;
    if (error is FileSystemException) {
      return const FileFailure('Unable to read PDF file.');
    }
    return const PdfFailure('Could not render PDF preview.');
  }

  void _putCache(String pdfPath, List<Uint8List> pages) {
    _cache[pdfPath] = pages;
    _cacheOrder.remove(pdfPath);
    _cacheOrder.addLast(pdfPath);

    while (_cacheOrder.length > _maxCacheEntries) {
      final oldest = _cacheOrder.removeFirst();
      _cache.remove(oldest);
    }
  }

  static Future<Uint8List> _defaultByteLoader(String pdfPath) async {
    return File(pdfPath).readAsBytes();
  }

  static double _defaultDpi() {
    final views = ui.PlatformDispatcher.instance.views;
    final devicePixelRatio = views.isNotEmpty
        ? views.first.devicePixelRatio
        : 2.0;
    return devicePixelRatio * 72;
  }

  static Future<List<Uint8List>> _defaultRasterizer(
    Uint8List bytes,
    double dpi,
  ) async {
    throw const NativeChannelFailure(
      'Native PDF rasterization is unavailable.',
    );
  }

  static Future<List<Uint8List>?> _tryNativeRasterize({
    required String pdfPath,
    required double dpi,
  }) async {
    if (!GetPlatform.isAndroid && !GetPlatform.isIOS) {
      return null;
    }

    try {
      final rawPages = await _nativeChannel.invokeMethod<List<dynamic>>(
        'rasterizePdf',
        <String, dynamic>{'path': pdfPath, 'dpi': dpi},
      );
      if (rawPages == null || rawPages.isEmpty) {
        return null;
      }

      final pages = <Uint8List>[];
      for (final item in rawPages) {
        if (item is Uint8List) {
          pages.add(item);
          continue;
        }
        if (item is ByteData) {
          pages.add(item.buffer.asUint8List());
          continue;
        }
        if (item is List<int>) {
          pages.add(Uint8List.fromList(item));
        }
      }

      return pages.isEmpty ? null : pages;
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e, st) {
      Log.warning(
        'Native PDF raster failed (${e.code}): ${e.message ?? ''}',
        tag: _tag,
      );
      Log.error(
        'Native PDF raster platform error',
        error: e,
        stackTrace: st,
        tag: _tag,
      );
      return null;
    } catch (e, st) {
      Log.warning('Native PDF raster unavailable, using fallback.', tag: _tag);
      Log.error(
        'Native PDF raster unknown error',
        error: e,
        stackTrace: st,
        tag: _tag,
      );
      return null;
    }
  }
}
