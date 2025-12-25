/// MAG PLOTTER 描画レイヤー
///
/// 地図上に描画中の図形と保存済み図形を表示するレイヤー
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

  const DrawingOverlay({
    super.key,
    required this.controller,
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
            layers.add(_buildPointsLayer());
            break;

          case DrawingMode.polyline:
            layers.add(_buildPolylineLayer());
            layers.add(_buildPointsLayer());
            break;

          case DrawingMode.circle:
            layers.add(_buildCircleLayer());
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
}

/// 保存済み図形を表示するレイヤー
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
              color: s.color.withValues(alpha: 0.3),
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
              strokeWidth: 2,
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
              color: s.color.withValues(alpha: 0.3),
              borderColor: s.color,
              borderStrokeWidth: 2,
            ))
        .toList();
    if (circles.isNotEmpty) {
      layers.add(CircleLayer(circles: circles));
    }

    // ラベル
    layers.add(_buildLabelsLayer(visibleShapes));

    return Stack(children: layers);
  }

  /// ラベルレイヤーの構築
  Widget _buildLabelsLayer(List<DrawingShape> shapes) {
    return MarkerLayer(
      markers: shapes.map((shape) {
        final center = shape.center;
        if (center == null) return null;

        return Marker(
          point: center,
          width: 120,
          height: 40,
          child: GestureDetector(
            onTap: () => onShapeTap?.call(shape),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.backgroundCard.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: shape.color),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    shape.name,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: shape.color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _getShapeMeasurement(shape),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 8,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
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
          return 'r: ${_formatDistance(shape.radius!)}';
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
    if (area >= 10000) {
      return '${(area / 10000).toStringAsFixed(2)} ha';
    } else {
      return '${area.toStringAsFixed(1)} m²';
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

