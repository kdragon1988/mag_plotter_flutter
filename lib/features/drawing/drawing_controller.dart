/// MAG PLOTTER 描画コントローラー
///
/// 地図上での図形描画を制御するコントローラー
/// ポリゴン、ポリライン、サークルの描画と管理
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/drawing_shape.dart';
import 'drawing_mode.dart';

/// 描画コントローラー
///
/// 図形の描画状態を管理し、完成した図形を通知
class DrawingController extends ChangeNotifier {
  /// 現在の描画モード
  DrawingMode _mode = DrawingMode.none;

  /// 描画中のポイントリスト
  final List<LatLng> _points = [];

  /// 選択中の色
  Color _selectedColor = AppColors.drawingOrange;

  /// サークルの中心点
  LatLng? _circleCenter;

  /// サークルの半径 [m]
  double _circleRadius = 0;

  /// 現在の描画モード
  DrawingMode get mode => _mode;

  /// 描画中のポイント
  List<LatLng> get points => List.unmodifiable(_points);

  /// 選択中の色
  Color get selectedColor => _selectedColor;

  /// サークル中心
  LatLng? get circleCenter => _circleCenter;

  /// サークル半径
  double get circleRadius => _circleRadius;

  /// 描画中かどうか
  bool get isDrawing => _mode.isDrawing;

  /// ポイントがあるかどうか
  bool get hasPoints => _points.isNotEmpty || _circleCenter != null;

  /// 描画モードを設定
  void setMode(DrawingMode mode) {
    if (_mode != mode) {
      clear();
      _mode = mode;
      notifyListeners();
    }
  }

  /// 色を設定
  void setColor(Color color) {
    _selectedColor = color;
    notifyListeners();
  }

  /// ポイントを追加
  void addPoint(LatLng point) {
    if (_mode == DrawingMode.circle) {
      if (_circleCenter == null) {
        // 最初のタップは中心点
        _circleCenter = point;
        _circleRadius = 0;
      } else {
        // 2回目のタップで半径確定
        _circleRadius = _calculateDistance(_circleCenter!, point);
      }
    } else {
      _points.add(point);
    }
    notifyListeners();
  }

  /// サークルの半径を更新（ドラッグ中）
  void updateCircleRadius(LatLng point) {
    if (_mode == DrawingMode.circle && _circleCenter != null) {
      _circleRadius = _calculateDistance(_circleCenter!, point);
      notifyListeners();
    }
  }

  /// 最後のポイントを削除（Undo）
  void undo() {
    if (_mode == DrawingMode.circle) {
      if (_circleRadius > 0) {
        _circleRadius = 0;
      } else {
        _circleCenter = null;
      }
    } else if (_points.isNotEmpty) {
      _points.removeLast();
    }
    notifyListeners();
  }

  /// すべてクリア
  void clear() {
    _points.clear();
    _circleCenter = null;
    _circleRadius = 0;
    notifyListeners();
  }

  /// 描画を完了して図形を生成
  DrawingShape? complete({
    required int missionId,
    required String name,
  }) {
    if (!canComplete) return null;

    final colorHex = _colorToHex(_selectedColor);
    DrawingShape? shape;

    switch (_mode) {
      case DrawingMode.polygon:
        if (_points.length >= 3) {
          shape = DrawingShape(
            missionId: missionId,
            type: ShapeType.polygon,
            name: name,
            colorHex: colorHex,
            coordinatesJson: DrawingShape.coordinatesToJson(_points),
          );
        }
        break;

      case DrawingMode.polyline:
        if (_points.length >= 2) {
          shape = DrawingShape(
            missionId: missionId,
            type: ShapeType.polyline,
            name: name,
            colorHex: colorHex,
            coordinatesJson: DrawingShape.coordinatesToJson(_points),
          );
        }
        break;

      case DrawingMode.circle:
        if (_circleCenter != null && _circleRadius > 0) {
          shape = DrawingShape(
            missionId: missionId,
            type: ShapeType.circle,
            name: name,
            colorHex: colorHex,
            coordinatesJson: DrawingShape.coordinatesToJson([_circleCenter!]),
            radius: _circleRadius,
          );
        }
        break;

      case DrawingMode.none:
        break;
    }

    if (shape != null) {
      clear();
    }

    return shape;
  }

  /// 完了可能かどうか
  bool get canComplete {
    switch (_mode) {
      case DrawingMode.polygon:
        return _points.length >= 3;
      case DrawingMode.polyline:
        return _points.length >= 2;
      case DrawingMode.circle:
        return _circleCenter != null && _circleRadius > 0;
      case DrawingMode.none:
        return false;
    }
  }

  /// 2点間の距離を計算 [m]
  double _calculateDistance(LatLng from, LatLng to) {
    const earthRadius = 6371000.0; // 地球の半径（メートル）
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLat = (to.latitude - from.latitude) * math.pi / 180;
    final dLng = (to.longitude - from.longitude) * math.pi / 180;

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  /// ポリゴンの面積を計算 [m²]
  double calculatePolygonArea() {
    if (_points.length < 3) return 0;

    const earthRadius = 6371000.0;
    double area = 0;

    for (int i = 0; i < _points.length; i++) {
      final j = (i + 1) % _points.length;
      final xi = _points[i].longitude * math.pi / 180;
      final yi = _points[i].latitude * math.pi / 180;
      final xj = _points[j].longitude * math.pi / 180;
      final yj = _points[j].latitude * math.pi / 180;

      area += (xj - xi) * (2 + math.sin(yi) + math.sin(yj));
    }

    area = area.abs() * earthRadius * earthRadius / 2;
    return area;
  }

  /// ポリラインの総距離を計算 [m]
  double calculateTotalDistance() {
    if (_points.length < 2) return 0;

    double total = 0;
    for (int i = 0; i < _points.length - 1; i++) {
      total += _calculateDistance(_points[i], _points[i + 1]);
    }
    return total;
  }

  /// サークルの面積を計算 [m²]
  double calculateCircleArea() {
    return math.pi * _circleRadius * _circleRadius;
  }

  /// 面積を表示用文字列に変換
  String formatArea(double area) {
    if (area >= 10000) {
      return '${(area / 10000).toStringAsFixed(2)} ha';
    } else {
      return '${area.toStringAsFixed(1)} m²';
    }
  }

  /// 距離を表示用文字列に変換
  String formatDistance(double distance) {
    if (distance >= 1000) {
      return '${(distance / 1000).toStringAsFixed(2)} km';
    } else {
      return '${distance.toStringAsFixed(1)} m';
    }
  }

  /// Colorを16進数文字列に変換
  String _colorToHex(Color color) {
    final a = (color.a * 255.0).round().clamp(0, 255);
    final r = (color.r * 255.0).round().clamp(0, 255);
    final g = (color.g * 255.0).round().clamp(0, 255);
    final b = (color.b * 255.0).round().clamp(0, 255);
    return '${a.toRadixString(16).padLeft(2, '0')}'
        '${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }
}

