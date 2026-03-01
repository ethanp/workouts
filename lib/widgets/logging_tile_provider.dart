import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

final _log = Logger('TileProxy');

/// A [TileProvider] that fetches tiles via HTTP and logs the
/// [X-Tile-Cache] response header (HIT / MISS) set by the tile proxy.
///
/// On construction it logs once whether the proxy URL or the direct-OSM
/// fallback is being used.
class LoggingCacheTileProvider extends TileProvider {
  LoggingCacheTileProvider(this._tileProxyUrl) {
    if (_tileProxyUrl.contains('openstreetmap.org')) {
      _log.warning(
        'TILE_PROXY_URL unset — fetching tiles directly from OSM (no cache).',
      );
    } else {
      _log.info('Map tiles routed through cache proxy: $_tileProxyUrl');
    }
  }

  final String _tileProxyUrl;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return _LoggedTileImage(url: getTileUrl(coordinates, options));
  }
}

class _LoggedTileImage extends ImageProvider<_LoggedTileImage> {
  const _LoggedTileImage({required this.url});

  final String url;

  @override
  Future<_LoggedTileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _LoggedTileImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _fetch(key, decode),
      scale: 1.0,
      debugLabel: url,
    );
  }

  Future<ui.Codec> _fetch(
    _LoggedTileImage key,
    ImageDecoderCallback decode,
  ) async {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw NetworkImageLoadException(
        statusCode: response.statusCode,
        uri: Uri.parse(url),
      );
    }

    final cacheStatus = response.headers['x-tile-cache'];
    if (cacheStatus != null) {
      _log.fine('$cacheStatus  ${Uri.parse(url).path}');
    }

    final buffer = await ui.ImmutableBuffer.fromUint8List(response.bodyBytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) =>
      other is _LoggedTileImage && other.url == url;

  @override
  int get hashCode => url.hashCode;
}
