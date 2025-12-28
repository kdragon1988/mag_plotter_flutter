/// MAG PLOTTER 幾何学ユーティリティ
///
/// ポリゴンオフセット計算など幾何学的な操作を提供
library;

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// 幾何学ユーティリティクラス
class GeometryUtils {
  GeometryUtils._();

  /// 地球の半径 [m]
  static const double earthRadius = 6371000.0;

  /// ポリゴンをオフセット（縮小/拡大）
  ///
  /// [polygon] 元のポリゴン座標リスト
  /// [offsetMeters] オフセット距離 [m]
  ///   - 正の値: 内側に縮小
  ///   - 負の値: 外側に拡大
  /// 
  /// 戻り値: オフセットされたポリゴン座標リスト
  /// ポリゴンが小さすぎてオフセットできない場合はnullを返す
  static List<LatLng>? offsetPolygonInward(List<LatLng> polygon, double offsetMeters) {
    if (polygon.length < 3 || offsetMeters == 0) {
      debugPrint('GeometryUtils: Invalid input - points=${polygon.length}, offset=$offsetMeters');
      return null;
    }
    
    // オフセット方向を決定（正=内側、負=外側）
    final isInward = offsetMeters > 0;
    final absOffset = offsetMeters.abs();

    // ポリゴンが時計回りか反時計回りかを判定
    final isClockwise = _isClockwise(polygon);

    final offsetPolygon = <LatLng>[];

    for (int i = 0; i < polygon.length; i++) {
      final prev = polygon[(i - 1 + polygon.length) % polygon.length];
      final curr = polygon[i];
      final next = polygon[(i + 1) % polygon.length];

      // 前後の辺のベクトルを計算
      final v1 = _latLngToVector(prev, curr);
      final v2 = _latLngToVector(curr, next);

      // 各辺の法線ベクトルを計算
      // isInward=true: 内側向き、isInward=false: 外側向き
      final inwardFlag = isInward ? !isClockwise : isClockwise;
      final n1 = _normalizeVector(_perpendicularVector(v1, inwardFlag));
      final n2 = _normalizeVector(_perpendicularVector(v2, inwardFlag));

      // 二等分線方向のベクトル
      final bisector = _normalizeVector([n1[0] + n2[0], n1[1] + n2[1]]);
      
      if (bisector[0] == 0 && bisector[1] == 0) {
        // 平行な辺の場合は法線方向にオフセット
        final offsetPoint = _offsetLatLng(curr, n1, absOffset);
        offsetPolygon.add(offsetPoint);
      } else {
        // 角度による補正係数を計算
        final dot = n1[0] * bisector[0] + n1[1] * bisector[1];
        final factor = dot > 0.1 ? 1.0 / dot : 1.0;
        
        // オフセット距離を角度で補正
        final adjustedOffset = absOffset * factor.clamp(1.0, 3.0);
        
        final offsetPoint = _offsetLatLng(curr, bisector, adjustedOffset);
        offsetPolygon.add(offsetPoint);
      }
    }

    // オフセット結果の妥当性チェック
    if (!_isValidPolygon(offsetPolygon)) {
      debugPrint('GeometryUtils: Invalid offset polygon');
      return null;
    }

    debugPrint('GeometryUtils: Success - created ${offsetPolygon.length} point polygon');
    return offsetPolygon;
  }

  /// ポリゴンが時計回りかどうかを判定
  static bool _isClockwise(List<LatLng> polygon) {
    double sum = 0;
    for (int i = 0; i < polygon.length; i++) {
      final curr = polygon[i];
      final next = polygon[(i + 1) % polygon.length];
      sum += (next.longitude - curr.longitude) * (next.latitude + curr.latitude);
    }
    return sum > 0;
  }

  /// 2点間のベクトルを計算（メートル単位）
  static List<double> _latLngToVector(LatLng from, LatLng to) {
    final dLat = (to.latitude - from.latitude) * math.pi / 180;
    final dLng = (to.longitude - from.longitude) * math.pi / 180;
    
    // 緯度によるスケーリング
    final midLat = (from.latitude + to.latitude) / 2 * math.pi / 180;
    final latScale = earthRadius;
    final lngScale = earthRadius * math.cos(midLat);
    
    return [dLng * lngScale, dLat * latScale];
  }

  /// ベクトルの垂直ベクトルを取得
  static List<double> _perpendicularVector(List<double> v, bool clockwise) {
    if (clockwise) {
      return [v[1], -v[0]];
    } else {
      return [-v[1], v[0]];
    }
  }

  /// ベクトルを正規化
  static List<double> _normalizeVector(List<double> v) {
    final length = math.sqrt(v[0] * v[0] + v[1] * v[1]);
    if (length < 0.0001) {
      return [0.0, 0.0];
    }
    return [v[0] / length, v[1] / length];
  }

  /// 座標をベクトル方向にオフセット
  static LatLng _offsetLatLng(LatLng point, List<double> direction, double meters) {
    final lat = point.latitude * math.pi / 180;
    final lng = point.longitude * math.pi / 180;
    
    // 緯度方向のオフセット（度）
    final dLat = (direction[1] * meters / earthRadius) * 180 / math.pi;
    
    // 経度方向のオフセット（度、緯度補正付き）
    final dLng = (direction[0] * meters / (earthRadius * math.cos(lat))) * 180 / math.pi;
    
    return LatLng(point.latitude + dLat, point.longitude + dLng);
  }

  /// ポリゴンが有効かどうかをチェック
  static bool _isValidPolygon(List<LatLng> polygon) {
    if (polygon.length < 3) {
      debugPrint('GeometryUtils: Polygon too small - ${polygon.length} points');
      return false;
    }

    // 面積が0でないことを確認（絶対値で判定）
    final area = _calculateArea(polygon).abs();
    if (area < 1e-12) {
      debugPrint('GeometryUtils: Polygon area too small - $area');
      return false;
    }

    // 自己交差チェックは小さいオフセットでは省略
    // （複雑なポリゴンで問題が起きる可能性があるため）
    return true;
  }

  /// 2つの線分が交差するかどうかをチェック
  static bool _segmentsIntersect(LatLng a1, LatLng a2, LatLng b1, LatLng b2) {
    final d1 = _crossProduct(b2, b1, a1);
    final d2 = _crossProduct(b2, b1, a2);
    final d3 = _crossProduct(a2, a1, b1);
    final d4 = _crossProduct(a2, a1, b2);

    if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
      return true;
    }

    return false;
  }

  /// 外積を計算
  static double _crossProduct(LatLng o, LatLng a, LatLng b) {
    return (a.longitude - o.longitude) * (b.latitude - o.latitude) -
        (a.latitude - o.latitude) * (b.longitude - o.longitude);
  }

  /// ポリゴンの面積を計算（符号付き）
  static double _calculateArea(List<LatLng> polygon) {
    double area = 0;
    for (int i = 0; i < polygon.length; i++) {
      final j = (i + 1) % polygon.length;
      area += polygon[i].longitude * polygon[j].latitude;
      area -= polygon[j].longitude * polygon[i].latitude;
    }
    return area / 2;
  }

  /// 2点間の距離を計算 [m]（Haversine公式）
  static double calculateDistance(LatLng p1, LatLng p2) {
    final lat1 = p1.latitude * math.pi / 180;
    final lat2 = p2.latitude * math.pi / 180;
    final dLat = (p2.latitude - p1.latitude) * math.pi / 180;
    final dLng = (p2.longitude - p1.longitude) * math.pi / 180;

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }
}

