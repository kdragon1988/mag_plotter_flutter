/// MAG PLOTTER 描画図形モデル
///
/// 地図上に描画した図形（ポリゴン、ライン、サークル）のデータモデル
/// ミッションに紐づいて保存される
library;

import 'dart:convert';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// 図形タイプ
enum ShapeType {
  /// ポリゴン（多角形）
  polygon,

  /// ポリライン（線）
  polyline,

  /// サークル（円）
  circle,
}

/// 描画図形エンティティ
///
/// 地図上に描画した図形の情報を保持
/// 座標はGeoJSON形式で保存
class DrawingShape {
  /// 図形ID（データベース自動採番）
  final int? id;

  /// 紐づくミッションID
  final int missionId;

  /// 図形タイプ
  final ShapeType type;

  /// 図形名
  final String name;

  /// 色（16進数文字列）
  final String colorHex;

  /// 座標（GeoJSON形式の文字列）
  final String coordinatesJson;

  /// 半径（サークルの場合のみ） [m]
  final double? radius;

  /// 表示するかどうか
  final bool isVisible;

  /// 辺の長さを表示するか
  final bool showEdgeLabels;

  /// 名前ラベルを表示するか
  final bool showNameLabel;

  /// 保安区域を表示するか（ポリゴンのみ）
  final bool showSecurityArea;

  /// 保安区域オフセット [m]（0-1000m）
  final double securityAreaOffset;

  /// 作成日時
  final DateTime createdAt;

  /// 更新日時
  final DateTime updatedAt;

  DrawingShape({
    this.id,
    required this.missionId,
    required this.type,
    required this.name,
    this.colorHex = 'FFFF9800',
    required this.coordinatesJson,
    this.radius,
    this.isVisible = true,
    this.showEdgeLabels = true,
    this.showNameLabel = true,
    this.showSecurityArea = false,
    this.securityAreaOffset = 30.0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 色をColorオブジェクトとして取得
  Color get color => Color(int.parse(colorHex, radix: 16));

  /// 座標リストを取得
  List<LatLng> get coordinates {
    try {
      final List<dynamic> coords = jsonDecode(coordinatesJson);
      return coords.map((coord) {
        if (coord is List && coord.length >= 2) {
          return LatLng(
            (coord[1] as num).toDouble(),
            (coord[0] as num).toDouble(),
          );
        }
        return const LatLng(0, 0);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// 中心座標を取得（サークルまたはポリゴンの重心）
  LatLng? get center {
    final coords = coordinates;
    if (coords.isEmpty) return null;

    if (type == ShapeType.circle && coords.isNotEmpty) {
      return coords.first;
    }

    // ポリゴン/ラインの重心を計算
    double latSum = 0;
    double lngSum = 0;
    for (final coord in coords) {
      latSum += coord.latitude;
      lngSum += coord.longitude;
    }
    return LatLng(latSum / coords.length, lngSum / coords.length);
  }

  /// Mapから図形を生成（DB読み込み用）
  factory DrawingShape.fromMap(Map<String, dynamic> map) {
    return DrawingShape(
      id: map['id'] as int?,
      missionId: map['mission_id'] as int,
      type: ShapeType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => ShapeType.polygon,
      ),
      name: map['name'] as String,
      colorHex: map['color_hex'] as String? ?? 'FFFF9800',
      coordinatesJson: map['coordinates_json'] as String,
      radius: (map['radius'] as num?)?.toDouble(),
      isVisible: (map['is_visible'] as int?) != 0,
      showEdgeLabels: (map['show_edge_labels'] as int?) != 0,
      showNameLabel: (map['show_name_label'] as int?) != 0,
      showSecurityArea: (map['show_security_area'] as int?) == 1,
      securityAreaOffset: (map['security_area_offset'] as num?)?.toDouble() ?? 30.0,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  /// 図形をMapに変換（DB書き込み用）
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'mission_id': missionId,
      'type': type.name,
      'name': name,
      'color_hex': colorHex,
      'coordinates_json': coordinatesJson,
      'radius': radius,
      'is_visible': isVisible ? 1 : 0,
      'show_edge_labels': showEdgeLabels ? 1 : 0,
      'show_name_label': showNameLabel ? 1 : 0,
      'show_security_area': showSecurityArea ? 1 : 0,
      'security_area_offset': securityAreaOffset,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// 座標リストからGeoJSON形式の文字列を生成
  static String coordinatesToJson(List<LatLng> coords) {
    final list = coords.map((c) => [c.longitude, c.latitude]).toList();
    return jsonEncode(list);
  }

  /// 色のHex文字列リスト
  static List<String> get colorOptions => [
        AppColors.drawingOrange.toHex(),
        AppColors.drawingBlue.toHex(),
        AppColors.drawingGreen.toHex(),
        AppColors.drawingRed.toHex(),
        AppColors.drawingPurple.toHex(),
        AppColors.drawingYellow.toHex(),
      ];

  /// 更新されたコピーを生成
  DrawingShape copyWith({
    int? id,
    int? missionId,
    ShapeType? type,
    String? name,
    String? colorHex,
    String? coordinatesJson,
    double? radius,
    bool? isVisible,
    bool? showEdgeLabels,
    bool? showNameLabel,
    bool? showSecurityArea,
    double? securityAreaOffset,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DrawingShape(
      id: id ?? this.id,
      missionId: missionId ?? this.missionId,
      type: type ?? this.type,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      coordinatesJson: coordinatesJson ?? this.coordinatesJson,
      radius: radius ?? this.radius,
      isVisible: isVisible ?? this.isVisible,
      showEdgeLabels: showEdgeLabels ?? this.showEdgeLabels,
      showNameLabel: showNameLabel ?? this.showNameLabel,
      showSecurityArea: showSecurityArea ?? this.showSecurityArea,
      securityAreaOffset: securityAreaOffset ?? this.securityAreaOffset,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'DrawingShape(id: $id, type: $type, name: $name)';
  }
}

/// Color拡張
extension ColorExtension on Color {
  /// 16進数文字列に変換
  String toHex() {
    final a = (this.a * 255.0).round().clamp(0, 255);
    final r = (this.r * 255.0).round().clamp(0, 255);
    final g = (this.g * 255.0).round().clamp(0, 255);
    final b = (this.b * 255.0).round().clamp(0, 255);
    return '${a.toRadixString(16).padLeft(2, '0')}'
        '${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }
}

