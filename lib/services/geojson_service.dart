/// GeoJSON読み込みサービス
/// 
/// ローカルのGeoJSONファイルを読み込み、マップ上に表示するための
/// ポリゴンデータに変換するサービス。
/// 
/// 【主な機能】
/// - assetsフォルダからGeoJSONファイルを読み込み
/// - GeoJSONをLatLngリストに変換
/// - フィーチャーごとのプロパティ取得
/// - ビューポートフィルタリングによるパフォーマンス最適化
/// - ポリゴン簡略化によるメモリ最適化
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

/// バウンディングボックス（境界矩形）
class BoundingBox {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  const BoundingBox({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  /// ポイントリストからバウンディングボックスを作成
  factory BoundingBox.fromPoints(List<LatLng> points) {
    if (points.isEmpty) {
      return const BoundingBox(minLat: 0, maxLat: 0, minLng: 0, maxLng: 0);
    }
    
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    
    return BoundingBox(
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
    );
  }

  /// 別のバウンディングボックスと交差するか判定
  bool intersects(BoundingBox other) {
    return !(maxLat < other.minLat ||
             minLat > other.maxLat ||
             maxLng < other.minLng ||
             minLng > other.maxLng);
  }

  /// 中心点を取得
  LatLng get center => LatLng(
    (minLat + maxLat) / 2,
    (minLng + maxLng) / 2,
  );
}

/// GeoJSONのフィーチャー（ポリゴン）
class GeoJsonFeature {
  /// プロパティ（名称、人口等）
  final Map<String, dynamic> properties;
  
  /// ポリゴンの座標リスト（外周のみ）
  final List<List<LatLng>> polygons;
  
  /// 各ポリゴンのバウンディングボックス
  final List<BoundingBox> boundingBoxes;

  GeoJsonFeature({
    required this.properties,
    required this.polygons,
    List<BoundingBox>? boundingBoxes,
  }) : boundingBoxes = boundingBoxes ?? 
         polygons.map((p) => BoundingBox.fromPoints(p)).toList();

  /// 市町村名を取得
  String? get municipalityName => properties['市町村名称'] as String?;
  
  /// 人口を取得
  int? get population => properties['人口'] as int?;
  
  /// 面積を取得（km²）
  double? get area => (properties['面積'] as num?)?.toDouble();
  
  /// ビューポートと交差するポリゴンをフィルタリング
  List<List<LatLng>> getVisiblePolygons(BoundingBox viewport) {
    final visible = <List<LatLng>>[];
    for (int i = 0; i < polygons.length; i++) {
      if (boundingBoxes[i].intersects(viewport)) {
        visible.add(polygons[i]);
      }
    }
    return visible;
  }
}

/// バックグラウンドでGeoJSONを解析するためのデータ
class _ParseParams {
  final String jsonString;
  final int simplifyThreshold;
  
  _ParseParams(this.jsonString, this.simplifyThreshold);
}

/// バックグラウンドでGeoJSONを解析
List<GeoJsonFeature> _parseGeoJsonInBackground(_ParseParams params) {
  final jsonData = json.decode(params.jsonString) as Map<String, dynamic>;
  final features = <GeoJsonFeature>[];
  final featureList = jsonData['features'] as List<dynamic>? ?? [];
  
  for (final feature in featureList) {
    final featureMap = feature as Map<String, dynamic>;
    final properties = featureMap['properties'] as Map<String, dynamic>? ?? {};
    final geometry = featureMap['geometry'] as Map<String, dynamic>?;
    
    if (geometry == null) continue;
    
    final geometryType = geometry['type'] as String?;
    final coordinates = geometry['coordinates'];
    
    if (coordinates == null) continue;
    
    final polygons = <List<LatLng>>[];
    
    if (geometryType == 'Polygon') {
      final rings = coordinates as List<dynamic>;
      if (rings.isNotEmpty) {
        final outerRing = _parseRingStatic(rings[0] as List<dynamic>, params.simplifyThreshold);
        if (outerRing.isNotEmpty) {
          polygons.add(outerRing);
        }
      }
    } else if (geometryType == 'MultiPolygon') {
      final multiPolygon = coordinates as List<dynamic>;
      for (final polygon in multiPolygon) {
        final rings = polygon as List<dynamic>;
        if (rings.isNotEmpty) {
          final outerRing = _parseRingStatic(rings[0] as List<dynamic>, params.simplifyThreshold);
          if (outerRing.isNotEmpty) {
            polygons.add(outerRing);
          }
        }
      }
    }
    
    if (polygons.isNotEmpty) {
      features.add(GeoJsonFeature(
        properties: properties,
        polygons: polygons,
      ));
    }
  }
  
  return features;
}

/// リング（座標の配列）をLatLngリストに変換（静的メソッド）
List<LatLng> _parseRingStatic(List<dynamic> ring, int simplifyThreshold) {
  final points = <LatLng>[];
  
  // 頂点数が閾値を超える場合は間引く
  final step = ring.length > simplifyThreshold ? (ring.length / simplifyThreshold).ceil() : 1;
  
  for (int i = 0; i < ring.length; i += step) {
    final coord = ring[i];
    if (coord is List && coord.length >= 2) {
      final lng = (coord[0] as num).toDouble();
      final lat = (coord[1] as num).toDouble();
      points.add(LatLng(lat, lng));
    }
  }
  
  // 最後の頂点を必ず含める（ポリゴンを閉じるため）
  if (ring.isNotEmpty && points.isNotEmpty) {
    final lastCoord = ring.last;
    if (lastCoord is List && lastCoord.length >= 2) {
      final lastLng = (lastCoord[0] as num).toDouble();
      final lastLat = (lastCoord[1] as num).toDouble();
      final lastPoint = LatLng(lastLat, lastLng);
      if (points.last != lastPoint) {
        points.add(lastPoint);
      }
    }
  }
  
  return points;
}

/// GeoJSONサービス
class GeoJsonService {
  /// キャッシュ（ファイル名 -> フィーチャーリスト）
  final Map<String, List<GeoJsonFeature>> _cache = {};
  
  /// ポリゴン簡略化の閾値（頂点数がこれを超えたら間引く）
  static const int _simplifyThreshold = 500;

  /// GeoJSONファイルを読み込む（バックグラウンド処理）
  /// 
  /// [fileName] assetsフォルダ内のファイル名
  /// 戻り値: GeoJsonFeatureのリスト
  Future<List<GeoJsonFeature>> loadGeoJson(String fileName) async {
    // キャッシュにあればそれを返す
    if (_cache.containsKey(fileName)) {
      return _cache[fileName]!;
    }

    try {
      // assetsからファイルを読み込む
      final jsonString = await rootBundle.loadString('assets/layers/$fileName');
      
      // バックグラウンドで解析（UIスレッドをブロックしない）
      final features = await compute(
        _parseGeoJsonInBackground,
        _ParseParams(jsonString, _simplifyThreshold),
      );
      
      // キャッシュに保存
      _cache[fileName] = features;
      
      return features;
    } catch (e) {
      // エラー時は空のリストを返す
      debugPrint('GeoJSON読み込みエラー ($fileName): $e');
      return [];
    }
  }

  /// ビューポート内のポリゴンのみを取得（高速フィルタリング）
  List<List<LatLng>> getVisiblePolygons(
    String fileName,
    BoundingBox viewport,
  ) {
    final features = _cache[fileName];
    if (features == null) return [];
    
    final visible = <List<LatLng>>[];
    for (final feature in features) {
      visible.addAll(feature.getVisiblePolygons(viewport));
    }
    return visible;
  }

  /// キャッシュをクリア
  void clearCache() {
    _cache.clear();
  }

  /// 特定のファイルのキャッシュをクリア
  void clearCacheFor(String fileName) {
    _cache.remove(fileName);
  }

  /// フィーチャーの総数を取得
  int getFeatureCount(String fileName) {
    return _cache[fileName]?.length ?? 0;
  }

  /// ポリゴンの総数を取得（フィーチャーが複数のポリゴンを持つ場合があるため）
  int getPolygonCount(String fileName) {
    final features = _cache[fileName];
    if (features == null) return 0;
    
    int count = 0;
    for (final feature in features) {
      count += feature.polygons.length;
    }
    return count;
  }
  
  /// データがキャッシュに存在するか確認
  bool isLoaded(String fileName) {
    return _cache.containsKey(fileName);
  }
}

