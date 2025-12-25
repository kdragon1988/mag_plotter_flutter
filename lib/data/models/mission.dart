/// MAG PLOTTER ミッションモデル
///
/// 調査ミッションのデータモデル
/// 1つのミッションに複数の計測ポイントが紐づく
library;

/// ミッションエンティティ
///
/// 現場調査の単位となるミッション情報を保持
class Mission {
  /// ミッションID（データベース自動採番）
  final int? id;

  /// ミッション名
  final String name;

  /// 場所名
  final String location;

  /// 担当者名
  final String assignee;

  /// 基準磁場値 [μT]
  final double referenceMag;

  /// 安全閾値 [μT]
  final double safeThreshold;

  /// 危険閾値 [μT]
  final double dangerThreshold;

  /// 計測間隔（秒）
  final double measurementInterval;

  /// メモ
  final String? memo;

  /// 作成日時
  final DateTime createdAt;

  /// 更新日時
  final DateTime updatedAt;

  /// 計測完了かどうか
  final bool isCompleted;

  Mission({
    this.id,
    required this.name,
    this.location = '',
    this.assignee = '',
    this.referenceMag = 46.0,
    this.safeThreshold = 10.0,
    this.dangerThreshold = 50.0,
    this.measurementInterval = 1.0,
    this.memo,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isCompleted = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Mapからミッションを生成（DB読み込み用）
  factory Mission.fromMap(Map<String, dynamic> map) {
    return Mission(
      id: map['id'] as int?,
      name: map['name'] as String,
      location: map['location'] as String? ?? '',
      assignee: map['assignee'] as String? ?? '',
      referenceMag: (map['reference_mag'] as num?)?.toDouble() ?? 46.0,
      safeThreshold: (map['safe_threshold'] as num?)?.toDouble() ?? 10.0,
      dangerThreshold: (map['danger_threshold'] as num?)?.toDouble() ?? 50.0,
      measurementInterval:
          (map['measurement_interval'] as num?)?.toDouble() ?? 1.0,
      memo: map['memo'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      isCompleted: (map['is_completed'] as int?) == 1,
    );
  }

  /// ミッションをMapに変換（DB書き込み用）
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'location': location,
      'assignee': assignee,
      'reference_mag': referenceMag,
      'safe_threshold': safeThreshold,
      'danger_threshold': dangerThreshold,
      'measurement_interval': measurementInterval,
      'memo': memo,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_completed': isCompleted ? 1 : 0,
    };
  }

  /// 更新されたコピーを生成
  Mission copyWith({
    int? id,
    String? name,
    String? location,
    String? assignee,
    double? referenceMag,
    double? safeThreshold,
    double? dangerThreshold,
    double? measurementInterval,
    String? memo,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isCompleted,
  }) {
    return Mission(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      assignee: assignee ?? this.assignee,
      referenceMag: referenceMag ?? this.referenceMag,
      safeThreshold: safeThreshold ?? this.safeThreshold,
      dangerThreshold: dangerThreshold ?? this.dangerThreshold,
      measurementInterval: measurementInterval ?? this.measurementInterval,
      memo: memo ?? this.memo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  String toString() {
    return 'Mission(id: $id, name: $name, location: $location)';
  }
}

