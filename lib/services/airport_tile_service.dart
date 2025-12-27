/// 空港周辺エリアタイルサービス
/// 
/// 国土地理院の「空港等の周辺空域」GeoJSONタイルを取得・管理するサービス。
/// タイル方式により、必要な範囲のみを動的に取得してパフォーマンスを最適化。
/// 
/// 【データソース】
/// - 提供元: 国土地理院（地理院地図）
/// - レイヤーID: kokuarea
/// - URL: https://maps.gsi.go.jp/xyz/kokuarea/{z}/{x}/{y}.geojson
/// - ズームレベル: 8〜18
/// - 参照: https://maps.gsi.go.jp/development/ichiran.html
library;

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'geojson_service.dart';

/// タイル座標
class TileCoord {
  final int x;
  final int y;
  final int z;

  const TileCoord(this.x, this.y, this.z);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TileCoord &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          z == other.z;

  @override
  int get hashCode => x.hashCode ^ y.hashCode ^ z.hashCode;

  @override
  String toString() => 'TileCoord($z/$x/$y)';
}

/// 空港周辺エリアタイルサービス
class AirportTileService {
  /// タイルURL テンプレート
  static const String _tileUrlTemplate = 
      'https://maps.gsi.go.jp/xyz/kokuarea/{z}/{x}/{y}.geojson';
  
  /// 対応ズームレベル
  static const int minZoom = 8;
  static const int maxZoom = 18;
  
  /// 取得に使用するズームレベル（データ密度が高いズーム14を使用）
  static const int _fetchZoom = 14;
  
  /// キャッシュ（タイル座標 -> ポリゴンリスト）
  final Map<TileCoord, List<List<LatLng>>> _cache = {};
  
  /// 読み込み中のタイル
  final Set<TileCoord> _loading = {};
  
  /// HTTPクライアント
  final http.Client _client = http.Client();

  /// ビューポートに基づいてタイルを取得
  /// 
  /// [viewport] 現在のマップ表示範囲
  /// [currentZoom] 現在のマップズームレベル
  /// [onUpdate] ポリゴン更新時のコールバック
  Future<void> loadTilesForViewport(
    BoundingBox viewport,
    void Function(List<List<LatLng>> polygons) onUpdate, {
    double currentZoom = 14.0,
  }) async {
    // マップズームに応じてフェッチズームを調整（広域表示時はタイル数を抑える）
    int fetchZoom;
    if (currentZoom < 10) {
      fetchZoom = 10;
    } else if (currentZoom < 12) {
      fetchZoom = 12;
    } else {
      fetchZoom = _fetchZoom; // 14
    }
    
    debugPrint('空港タイル: ビューポート (${viewport.minLat.toStringAsFixed(2)}, ${viewport.minLng.toStringAsFixed(2)}) - (${viewport.maxLat.toStringAsFixed(2)}, ${viewport.maxLng.toStringAsFixed(2)}), フェッチズーム: $fetchZoom');
    
    // 必要なタイル座標を計算
    final tiles = _getTilesForBounds(viewport, fetchZoom);
    
    // タイル数が多すぎる場合は制限（パフォーマンス保護）
    final maxTiles = 25;
    final tilesToFetch = tiles.length > maxTiles ? tiles.sublist(0, maxTiles) : tiles;
    debugPrint('空港タイル: 必要タイル数 ${tiles.length}, 取得数 ${tilesToFetch.length}');
    
    // 新しいタイルのみ取得
    final newTiles = tilesToFetch.where((t) => !_cache.containsKey(t) && !_loading.contains(t)).toList();
    debugPrint('空港タイル: 新規タイル数 ${newTiles.length}');
    
    if (newTiles.isEmpty) {
      // キャッシュ済みのポリゴンを返す
      final cached = _getPolygonsForTiles(tilesToFetch);
      debugPrint('空港タイル: キャッシュから ${cached.length} ポリゴン返却');
      onUpdate(cached);
      return;
    }
    
    // 並列で取得（最大5並列）
    for (var i = 0; i < newTiles.length; i += 5) {
      final batch = newTiles.skip(i).take(5);
      await Future.wait(batch.map((tile) => _fetchTile(tile)));
    }
    
    // 更新を通知
    final result = _getPolygonsForTiles(tilesToFetch);
    debugPrint('空港タイル: 合計 ${result.length} ポリゴン取得');
    onUpdate(result);
  }

  /// タイル座標リストからポリゴンを取得
  List<List<LatLng>> _getPolygonsForTiles(List<TileCoord> tiles) {
    final polygons = <List<LatLng>>[];
    for (final tile in tiles) {
      final cached = _cache[tile];
      if (cached != null) {
        polygons.addAll(cached);
      }
    }
    return polygons;
  }

  /// 単一タイルを取得
  Future<void> _fetchTile(TileCoord tile) async {
    if (_loading.contains(tile)) return;
    _loading.add(tile);
    
    try {
      final url = _tileUrlTemplate
          .replaceAll('{z}', tile.z.toString())
          .replaceAll('{x}', tile.x.toString())
          .replaceAll('{y}', tile.y.toString());
      
      debugPrint('空港タイル取得中: $url');
      
      final response = await _client.get(Uri.parse(url));
      
      debugPrint('空港タイル応答: ${response.statusCode} (${response.body.length} bytes)');
      
      if (response.statusCode == 200) {
        final polygons = await compute(_parseGeoJsonTile, response.body);
        _cache[tile] = polygons;
        debugPrint('空港タイルパース完了: ${polygons.length} polygons');
      } else if (response.statusCode == 404) {
        // タイルが存在しない（空港エリアがない）
        _cache[tile] = [];
        debugPrint('空港タイル404: このエリアに空港なし');
      } else {
        debugPrint('空港タイル取得エラー ($tile): ${response.statusCode}');
        _cache[tile] = [];
      }
    } catch (e) {
      debugPrint('空港タイル取得例外 ($tile): $e');
      _cache[tile] = [];
    } finally {
      _loading.remove(tile);
    }
  }

  /// 境界矩形から必要なタイル座標を計算
  List<TileCoord> _getTilesForBounds(BoundingBox bounds, int zoom) {
    final minTile = _latLngToTile(LatLng(bounds.maxLat, bounds.minLng), zoom);
    final maxTile = _latLngToTile(LatLng(bounds.minLat, bounds.maxLng), zoom);
    
    final tiles = <TileCoord>[];
    for (int x = minTile.x; x <= maxTile.x; x++) {
      for (int y = minTile.y; y <= maxTile.y; y++) {
        tiles.add(TileCoord(x, y, zoom));
      }
    }
    return tiles;
  }

  /// 緯度経度からタイル座標に変換
  TileCoord _latLngToTile(LatLng latLng, int zoom) {
    final n = math.pow(2, zoom).toDouble();
    final x = ((latLng.longitude + 180) / 360 * n).floor();
    final latRad = latLng.latitude * math.pi / 180;
    final y = ((1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) / 2 * n).floor();
    return TileCoord(x.clamp(0, n.toInt() - 1), y.clamp(0, n.toInt() - 1), zoom);
  }

  /// キャッシュをクリア
  void clearCache() {
    _cache.clear();
    _loading.clear();
  }

  /// 読み込み済みポリゴン数を取得
  int get cachedPolygonCount {
    int count = 0;
    for (final polygons in _cache.values) {
      count += polygons.length;
    }
    return count;
  }

  /// リソースを解放
  void dispose() {
    _client.close();
    clearCache();
  }
}

/// GeoJSONタイルをパース（バックグラウンド処理用）
List<List<LatLng>> _parseGeoJsonTile(String jsonString) {
  try {
    final jsonData = json.decode(jsonString) as Map<String, dynamic>;
    final features = jsonData['features'] as List<dynamic>? ?? [];
    final polygons = <List<LatLng>>[];
    
    for (final feature in features) {
      final featureMap = feature as Map<String, dynamic>;
      final geometry = featureMap['geometry'] as Map<String, dynamic>?;
      if (geometry == null) continue;
      
      final geometryType = geometry['type'] as String?;
      final coordinates = geometry['coordinates'];
      if (coordinates == null) continue;
      
      if (geometryType == 'Polygon') {
        final rings = coordinates as List<dynamic>;
        if (rings.isNotEmpty) {
          final outerRing = _parseRing(rings[0] as List<dynamic>);
          if (outerRing.isNotEmpty) {
            polygons.add(outerRing);
          }
        }
      } else if (geometryType == 'MultiPolygon') {
        final multiPolygon = coordinates as List<dynamic>;
        for (final polygon in multiPolygon) {
          final rings = polygon as List<dynamic>;
          if (rings.isNotEmpty) {
            final outerRing = _parseRing(rings[0] as List<dynamic>);
            if (outerRing.isNotEmpty) {
              polygons.add(outerRing);
            }
          }
        }
      }
    }
    
    return polygons;
  } catch (e) {
    debugPrint('GeoJSONタイルパースエラー: $e');
    return [];
  }
}

/// リングをLatLngリストに変換
List<LatLng> _parseRing(List<dynamic> ring) {
  final points = <LatLng>[];
  for (final coord in ring) {
    if (coord is List && coord.length >= 2) {
      final lng = (coord[0] as num).toDouble();
      final lat = (coord[1] as num).toDouble();
      points.add(LatLng(lat, lng));
    }
  }
  return points;
}

