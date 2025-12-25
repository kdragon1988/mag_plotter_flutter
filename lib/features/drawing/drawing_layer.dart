/// MAG PLOTTER 描画レイヤー
///
/// 地図上に描画中の図形と保存済み図形を表示するレイヤー
/// 各辺の長さを地図上に直接表示
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/drawing_shape.dart';
import 'drawing_controller.dart';
import 'drawing_mode.dart';

/// 描画中の図形を表示するレイヤー
class DrawingOverlay extends StatelessWidget {
  /// 描画コントローラー
  final DrawingController controller;

  /// 辺の長さを表示するか
  final bool showEdgeLabels;

  const DrawingOverlay({
    super.key,
    required this.controller,
    this.showEdgeLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final layers = <Widget>[];

        switch (controller.mode) {
          case DrawingMode.polygon:
            layers.add(_buildPolygonLayer());
            if (showEdgeLabels) {
              layers.add(_buildEdgeLabelsLayer(closed: true));
            }
            layers.add(_buildPointsLayer());
            break;

          case DrawingMode.polyline:
            layers.add(_buildPolylineLayer());
            if (showEdgeLabels) {
              layers.add(_buildEdgeLabelsLayer(closed: false));
            }
            layers.add(_buildPointsLayer());
            break;

          case DrawingMode.circle:
            layers.add(_buildCircleLayer());
            if (showEdgeLabels) {
              layers.add(_buildRadiusLabel());
            }
            if (controller.circleCenter != null) {
              layers.add(_buildCircleCenterMarker());
            }
            break;

          case DrawingMode.none:
            break;
        }

        return Stack(children: layers);
      },
    );
  }

  /// ポリゴンレイヤーの構築
  Widget _buildPolygonLayer() {
    if (controller.points.length < 3) {
      return _buildPolylineLayer(); // 3点未満は線として表示
    }

    return PolygonLayer(
      polygons: [
        Polygon(
          points: controller.points,
          color: controller.selectedColor.withValues(alpha: 0.3),
          borderColor: controller.selectedColor,
          borderStrokeWidth: 3,
          isFilled: true,
        ),
      ],
    );
  }

  /// ポリラインレイヤーの構築
  Widget _buildPolylineLayer() {
    if (controller.points.length < 2) {
      return const SizedBox.shrink();
    }

    return PolylineLayer(
      polylines: [
        Polyline(
          points: controller.points,
          color: controller.selectedColor,
          strokeWidth: 3,
        ),
      ],
    );
  }

  /// 各辺の長さラベルを表示
  Widget _buildEdgeLabelsLayer({required bool closed}) {
    final points = controller.points;
    if (points.length < 2) return const SizedBox.shrink();

    final markers = <Marker>[];

    // 各辺のラベル
    for (int i = 0; i < points.length - 1; i++) {
      final from = points[i];
      final to = points[i + 1];
      final midpoint = _getMidpoint(from, to);
      final distance = _calculateDistance(from, to);

      markers.add(_createEdgeLabelMarker(
        point: midpoint,
        distance: distance,
        color: controller.selectedColor,
      ));
    }

    // 閉じるポリゴンの場合、最後の辺も表示
    if (closed && points.length >= 3) {
      final from = points.last;
      final to = points.first;
      final midpoint = _getMidpoint(from, to);
      final distance = _calculateDistance(from, to);

      markers.add(_createEdgeLabelMarker(
        point: midpoint,
        distance: distance,
        color: AppColors.statusWarning, // 閉じる辺は黄色
        isClosing: true,
      ));
    }

    return MarkerLayer(markers: markers);
  }

  /// 辺のラベルマーカーを作成（ミニマルデザイン）
  Marker _createEdgeLabelMarker({
    required LatLng point,
    required double distance,
    required Color color,
    bool isClosing = false,
  }) {
    return Marker(
      point: point,
      width: 56,
      height: 18,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          _formatDistance(distance),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: isClosing ? AppColors.statusWarning : color,
          ),
        ),
      ),
    );
  }

  /// 円の半径ラベルを表示（ミニマルデザイン）
  Widget _buildRadiusLabel() {
    if (controller.circleCenter == null || controller.circleRadius <= 0) {
      return const SizedBox.shrink();
    }

    // 半径線の終点（中心から右方向）
    final center = controller.circleCenter!;
    final radiusEndLat = center.latitude;
    final radiusEndLng = center.longitude +
        (controller.circleRadius / 111320) / math.cos(center.latitude * math.pi / 180);
    final radiusEnd = LatLng(radiusEndLat, radiusEndLng);
    final midpoint = _getMidpoint(center, radiusEnd);

    return Stack(
      children: [
        // 半径線
        PolylineLayer(
          polylines: [
            Polyline(
              points: [center, radiusEnd],
              color: controller.selectedColor.withValues(alpha: 0.6),
              strokeWidth: 1.5,
            ),
          ],
        ),
        // 半径ラベル
        MarkerLayer(
          markers: [
            Marker(
              point: midpoint,
              width: 60,
              height: 18,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  'r ${_formatDistance(controller.circleRadius)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: controller.selectedColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// サークルレイヤーの構築
  Widget _buildCircleLayer() {
    if (controller.circleCenter == null || controller.circleRadius <= 0) {
      return const SizedBox.shrink();
    }

    return CircleLayer(
      circles: [
        CircleMarker(
          point: controller.circleCenter!,
          radius: controller.circleRadius,
          useRadiusInMeter: true,
          color: controller.selectedColor.withValues(alpha: 0.3),
          borderColor: controller.selectedColor,
          borderStrokeWidth: 3,
        ),
      ],
    );
  }

  /// ポイントマーカーレイヤーの構築
  Widget _buildPointsLayer() {
    if (controller.points.isEmpty) {
      return const SizedBox.shrink();
    }

    return MarkerLayer(
      markers: controller.points.asMap().entries.map((entry) {
        final index = entry.key;
        final point = entry.value;
        final isFirst = index == 0;
        final isLast = index == controller.points.length - 1;

        return Marker(
          point: point,
          width: 20,
          height: 20,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFirst
                  ? AppColors.statusSafe
                  : isLast
                      ? AppColors.accentPrimary
                      : controller.selectedColor,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: controller.selectedColor.withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: isFirst || isLast
                ? Center(
                    child: Text(
                      isFirst ? 'S' : 'E',
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }

  /// サークル中心マーカーの構築
  Widget _buildCircleCenterMarker() {
    return MarkerLayer(
      markers: [
        Marker(
          point: controller.circleCenter!,
          width: 24,
          height: 24,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: controller.selectedColor,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(
              Icons.add,
              size: 14,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  /// 2点の中点を取得
  LatLng _getMidpoint(LatLng from, LatLng to) {
    return LatLng(
      (from.latitude + to.latitude) / 2,
      (from.longitude + to.longitude) / 2,
    );
  }

  /// 2点間の距離を計算 [m]
  double _calculateDistance(LatLng from, LatLng to) {
    const earthRadius = 6371000.0;
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLat = (to.latitude - from.latitude) * math.pi / 180;
    final dLng = (to.longitude - from.longitude) * math.pi / 180;

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  /// 距離をフォーマット
  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(2)}km';
    } else {
      return '${meters.toStringAsFixed(1)}m';
    }
  }
}

/// 保存済み図形を表示するレイヤー
/// 
/// シンプルな表示：図形 + 中央に名前と面積/距離のみ
/// 辺の長さは表示しない（描画中のみ表示）
class SavedShapesLayer extends StatelessWidget {
  /// 表示する図形リスト
  final List<DrawingShape> shapes;

  /// 図形タップ時のコールバック
  final void Function(DrawingShape)? onShapeTap;

  const SavedShapesLayer({
    super.key,
    required this.shapes,
    this.onShapeTap,
  });

  @override
  Widget build(BuildContext context) {
    final visibleShapes = shapes.where((s) => s.isVisible).toList();
    if (visibleShapes.isEmpty) return const SizedBox.shrink();

    final layers = <Widget>[];

    // ポリゴン
    final polygons = visibleShapes
        .where((s) => s.type == ShapeType.polygon)
        .map((s) => Polygon(
              points: s.coordinates,
              color: s.color.withValues(alpha: 0.2),
              borderColor: s.color,
              borderStrokeWidth: 2,
              isFilled: true,
            ))
        .toList();
    if (polygons.isNotEmpty) {
      layers.add(PolygonLayer(polygons: polygons));
    }

    // ポリライン
    final polylines = visibleShapes
        .where((s) => s.type == ShapeType.polyline)
        .map((s) => Polyline(
              points: s.coordinates,
              color: s.color,
              strokeWidth: 2.5,
            ))
        .toList();
    if (polylines.isNotEmpty) {
      layers.add(PolylineLayer(polylines: polylines));
    }

    // サークル
    final circles = visibleShapes
        .where((s) => s.type == ShapeType.circle && s.radius != null)
        .map((s) => CircleMarker(
              point: s.coordinates.first,
              radius: s.radius!,
              useRadiusInMeter: true,
              color: s.color.withValues(alpha: 0.2),
              borderColor: s.color,
              borderStrokeWidth: 2,
            ))
        .toList();
    if (circles.isNotEmpty) {
      layers.add(CircleLayer(circles: circles));
    }

    // 辺の長さラベル（設定がONの図形のみ）
    layers.add(_buildEdgeLabelsLayer(visibleShapes));

    // 名前ラベル（設定がONの図形のみ）
    layers.add(_buildNameLabelsLayer(visibleShapes));

    return Stack(children: layers);
  }

  /// 辺の長さラベルレイヤー
  Widget _buildEdgeLabelsLayer(List<DrawingShape> shapes) {
    final markers = <Marker>[];

    for (final shape in shapes.where((s) => s.showEdgeLabels)) {
      if (shape.type == ShapeType.circle) {
        // サークルの場合は半径ラベル
        if (shape.radius != null && shape.coordinates.isNotEmpty) {
          final center = shape.coordinates.first;
          final radiusEndLat = center.latitude;
          final radiusEndLng = center.longitude +
              (shape.radius! / 111320) /
                  math.cos(center.latitude * math.pi / 180);
          final radiusEnd = LatLng(radiusEndLat, radiusEndLng);
          final midpoint = LatLng(
            (center.latitude + radiusEnd.latitude) / 2,
            (center.longitude + radiusEnd.longitude) / 2,
          );

          markers.add(_createEdgeLabelMarker(
            point: midpoint,
            text: 'r ${_formatDistance(shape.radius!)}',
            color: shape.color,
          ));
        }
      } else {
        // ポリゴン/ポリラインの場合は各辺のラベル
        final points = shape.coordinates;
        if (points.length >= 2) {
          for (int i = 0; i < points.length - 1; i++) {
            final from = points[i];
            final to = points[i + 1];
            final midpoint = LatLng(
              (from.latitude + to.latitude) / 2,
              (from.longitude + to.longitude) / 2,
            );
            final distance = _calculateDistance(from, to);

            markers.add(_createEdgeLabelMarker(
              point: midpoint,
              text: _formatDistance(distance),
              color: shape.color,
            ));
          }

          // ポリゴンの閉じる辺
          if (shape.type == ShapeType.polygon && points.length >= 3) {
            final from = points.last;
            final to = points.first;
            final midpoint = LatLng(
              (from.latitude + to.latitude) / 2,
              (from.longitude + to.longitude) / 2,
            );
            final distance = _calculateDistance(from, to);

            markers.add(_createEdgeLabelMarker(
              point: midpoint,
              text: _formatDistance(distance),
              color: shape.color,
            ));
          }
        }
      }
    }

    return MarkerLayer(markers: markers);
  }

  /// 辺のラベルマーカーを作成
  Marker _createEdgeLabelMarker({
    required LatLng point,
    required String text,
    required Color color,
  }) {
    return Marker(
      point: point,
      width: 56,
      height: 18,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  /// 名前ラベルレイヤー（名前のみ表示）
  Widget _buildNameLabelsLayer(List<DrawingShape> shapes) {
    return MarkerLayer(
      markers: shapes.where((s) => s.showNameLabel).map((shape) {
        final center = shape.center;
        if (center == null) return null;

        return Marker(
          point: center,
          width: 100,
          height: 24,
          child: GestureDetector(
            onTap: () => onShapeTap?.call(shape),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: shape.color.withValues(alpha: 0.6),
                  width: 1,
                ),
              ),
              child: Text(
                shape.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      }).whereType<Marker>().toList(),
    );
  }

  /// 図形の計測値を取得
  String _getShapeMeasurement(DrawingShape shape) {
    switch (shape.type) {
      case ShapeType.polygon:
        final area = _calculatePolygonArea(shape.coordinates);
        return _formatArea(area);

      case ShapeType.polyline:
        final distance = _calculateTotalDistance(shape.coordinates);
        return _formatDistance(distance);

      case ShapeType.circle:
        if (shape.radius != null) {
          final area = math.pi * shape.radius! * shape.radius!;
          return _formatArea(area);
        }
        return '';
    }
  }

  double _calculatePolygonArea(List<LatLng> points) {
    if (points.length < 3) return 0;
    const earthRadius = 6371000.0;
    double area = 0;

    for (int i = 0; i < points.length; i++) {
      final j = (i + 1) % points.length;
      final xi = points[i].longitude * math.pi / 180;
      final yi = points[i].latitude * math.pi / 180;
      final xj = points[j].longitude * math.pi / 180;
      final yj = points[j].latitude * math.pi / 180;
      area += (xj - xi) * (2 + math.sin(yi) + math.sin(yj));
    }

    return (area.abs() * earthRadius * earthRadius / 2);
  }

  double _calculateTotalDistance(List<LatLng> points) {
    if (points.length < 2) return 0;
    double total = 0;
    for (int i = 0; i < points.length - 1; i++) {
      total += _calculateDistance(points[i], points[i + 1]);
    }
    return total;
  }

  double _calculateDistance(LatLng from, LatLng to) {
    const earthRadius = 6371000.0;
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLat = (to.latitude - from.latitude) * math.pi / 180;
    final dLng = (to.longitude - from.longitude) * math.pi / 180;

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  String _formatArea(double area) {
    if (area >= 1000000) {
      return '${(area / 1000000).toStringAsFixed(2)} km²';
    } else {
      return '${area.toStringAsFixed(0)} m²';
    }
  }

  String _formatDistance(double distance) {
    if (distance >= 1000) {
      return '${(distance / 1000).toStringAsFixed(2)} km';
    } else {
      return '${distance.toStringAsFixed(1)} m';
    }
  }
}
