/// MAG PLOTTER 計測レイヤーモデル
///
/// 磁場計測データをグループ化するためのレイヤー
/// 点群の表示設定（サイズ、ぼかし）を持つ
library;

import 'package:flutter/material.dart';

/// 計測レイヤーエンティティ
///
/// 計測データを分類・管理するためのレイヤー
class MeasurementLayer {
  /// レイヤーID（データベース自動採番）
  final int? id;

  /// 紐づくミッションID
  final int missionId;

  /// レイヤー名
  final String name;

  /// レイヤーカラー
  final Color color;

  /// 点のサイズ（直径）[m]（実世界サイズ）
  final double pointSize;

  /// ぼかし強度（0.0〜1.0）
  final double blurIntensity;

  /// 表示/非表示
  final bool isVisible;

  /// 作成日時
  final DateTime createdAt;

  /// 更新日時
  final DateTime updatedAt;

  MeasurementLayer({
    this.id,
    required this.missionId,
    required this.name,
    this.color = Colors.cyan,
    this.pointSize = 0.5,
    this.blurIntensity = 0.0,
    this.isVisible = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Mapから生成（DB読み込み用）
  factory MeasurementLayer.fromMap(Map<String, dynamic> map) {
    return MeasurementLayer(
      id: map['id'] as int?,
      missionId: map['mission_id'] as int,
      name: map['name'] as String,
      color: Color(int.parse(map['color_hex'] as String, radix: 16)),
      pointSize: (map['point_size'] as num?)?.toDouble() ?? 0.5,
      blurIntensity: (map['blur_intensity'] as num?)?.toDouble() ?? 0.0,
      isVisible: (map['is_visible'] as int?) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  /// Mapに変換（DB書き込み用）
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'mission_id': missionId,
      'name': name,
      'color_hex': color.value.toRadixString(16).padLeft(8, '0').toUpperCase(),
      'point_size': pointSize,
      'blur_intensity': blurIntensity,
      'is_visible': isVisible ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// コピーを作成
  MeasurementLayer copyWith({
    int? id,
    int? missionId,
    String? name,
    Color? color,
    double? pointSize,
    double? blurIntensity,
    bool? isVisible,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MeasurementLayer(
      id: id ?? this.id,
      missionId: missionId ?? this.missionId,
      name: name ?? this.name,
      color: color ?? this.color,
      pointSize: pointSize ?? this.pointSize,
      blurIntensity: blurIntensity ?? this.blurIntensity,
      isVisible: isVisible ?? this.isVisible,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'MeasurementLayer(id: $id, name: $name, pointSize: $pointSize, blur: $blurIntensity)';
  }
}


