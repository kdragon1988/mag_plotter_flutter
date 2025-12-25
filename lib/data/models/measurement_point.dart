/// MAG PLOTTER 計測ポイントモデル
///
/// 磁場計測データの1ポイント分を表すモデル
/// ミッションに紐づいて保存される
library;

/// 計測ポイントエンティティ
///
/// 1回の磁場計測のデータを保持
class MeasurementPoint {
  /// ポイントID（データベース自動採番）
  final int? id;

  /// 紐づくミッションID
  final int missionId;

  /// 緯度
  final double latitude;

  /// 経度
  final double longitude;

  /// 高度 [m]
  final double? altitude;

  /// 位置精度 [m]
  final double? accuracy;

  /// X軸磁場 [μT]
  final double magX;

  /// Y軸磁場 [μT]
  final double magY;

  /// Z軸磁場 [μT]
  final double magZ;

  /// 総磁場強度 [μT]
  final double magField;

  /// ノイズ値（基準値との差） [μT]
  final double noise;

  /// 計測日時
  final DateTime timestamp;

  /// メモ
  final String? memo;

  MeasurementPoint({
    this.id,
    required this.missionId,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    this.magX = 0,
    this.magY = 0,
    this.magZ = 0,
    required this.magField,
    required this.noise,
    DateTime? timestamp,
    this.memo,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Mapから計測ポイントを生成（DB読み込み用）
  factory MeasurementPoint.fromMap(Map<String, dynamic> map) {
    return MeasurementPoint(
      id: map['id'] as int?,
      missionId: map['mission_id'] as int,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      altitude: (map['altitude'] as num?)?.toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      magX: (map['mag_x'] as num?)?.toDouble() ?? 0,
      magY: (map['mag_y'] as num?)?.toDouble() ?? 0,
      magZ: (map['mag_z'] as num?)?.toDouble() ?? 0,
      magField: (map['mag_field'] as num).toDouble(),
      noise: (map['noise'] as num).toDouble(),
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'] as String)
          : null,
      memo: map['memo'] as String?,
    );
  }

  /// 計測ポイントをMapに変換（DB書き込み用）
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'mission_id': missionId,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'accuracy': accuracy,
      'mag_x': magX,
      'mag_y': magY,
      'mag_z': magZ,
      'mag_field': magField,
      'noise': noise,
      'timestamp': timestamp.toIso8601String(),
      'memo': memo,
    };
  }

  /// ステータスを取得
  ///
  /// [safeThreshold] 安全閾値
  /// [dangerThreshold] 危険閾値
  MeasurementStatus getStatus({
    double safeThreshold = 10.0,
    double dangerThreshold = 50.0,
  }) {
    if (noise < safeThreshold) {
      return MeasurementStatus.safe;
    } else if (noise < dangerThreshold) {
      return MeasurementStatus.warning;
    } else {
      return MeasurementStatus.danger;
    }
  }

  @override
  String toString() {
    return 'MeasurementPoint(id: $id, lat: $latitude, lng: $longitude, '
        'magField: ${magField.toStringAsFixed(1)}μT, '
        'noise: ${noise.toStringAsFixed(1)}μT)';
  }
}

/// 計測ステータス
enum MeasurementStatus {
  /// 安全
  safe,

  /// 警告
  warning,

  /// 危険
  danger,
}

