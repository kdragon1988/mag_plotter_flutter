/// MAG PLOTTER 設定サービス
///
/// アプリ全体の設定値をSharedPreferencesで管理する
/// 磁場計測の閾値、計測間隔などを永続化
library;

import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';

/// 設定サービス
///
/// シングルトンパターンでアプリ設定を管理
/// SharedPreferencesを使用して設定を永続化
class SettingsService {
  /// シングルトンインスタンス
  static final SettingsService _instance = SettingsService._internal();

  /// ファクトリーコンストラクタ
  factory SettingsService() => _instance;

  /// プライベートコンストラクタ
  SettingsService._internal();

  /// SharedPreferencesインスタンス
  SharedPreferences? _prefs;

  // ============================================
  // SharedPreferencesキー
  // ============================================

  /// 基準磁場値キー
  static const String _keyReferenceMag = 'reference_mag';

  /// 安全閾値キー
  static const String _keySafeThreshold = 'safe_threshold';

  /// 危険閾値キー
  static const String _keyDangerThreshold = 'danger_threshold';

  /// 計測間隔キー
  static const String _keyMeasurementInterval = 'measurement_interval';

  /// 自動計測モードキー
  static const String _keyAutoMeasurement = 'auto_measurement';

  /// 地図タイプキー
  static const String _keyMapType = 'map_type';

  // ============================================
  // 初期化
  // ============================================

  /// サービスを初期化
  ///
  /// アプリ起動時に呼び出し、SharedPreferencesを初期化
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// SharedPreferencesが初期化済みか確認
  void _ensureInitialized() {
    if (_prefs == null) {
      throw StateError(
        'SettingsService.initialize()が呼び出されていません。'
        'main()内で初期化してください。',
      );
    }
  }

  // ============================================
  // 基準磁場値
  // ============================================

  /// 基準磁場値を取得 [μT]
  ///
  /// 未設定の場合はデフォルト値（46.0μT）を返す
  double get referenceMag {
    _ensureInitialized();
    return _prefs!.getDouble(_keyReferenceMag) ??
        AppConstants.defaultReferenceMag;
  }

  /// 基準磁場値を設定 [μT]
  ///
  /// [value] 設定する基準磁場値（0以上）
  Future<void> setReferenceMag(double value) async {
    _ensureInitialized();
    if (value < 0) {
      throw ArgumentError('基準磁場値は0以上である必要があります: $value');
    }
    await _prefs!.setDouble(_keyReferenceMag, value);
  }

  // ============================================
  // 安全閾値
  // ============================================

  /// 安全閾値を取得 [μT]
  ///
  /// この値未満のノイズは「安全」と判定
  double get safeThreshold {
    _ensureInitialized();
    return _prefs!.getDouble(_keySafeThreshold) ??
        AppConstants.defaultSafeThreshold;
  }

  /// 安全閾値を設定 [μT]
  ///
  /// [value] 設定する安全閾値（0以上）
  Future<void> setSafeThreshold(double value) async {
    _ensureInitialized();
    if (value < 0) {
      throw ArgumentError('安全閾値は0以上である必要があります: $value');
    }
    await _prefs!.setDouble(_keySafeThreshold, value);
  }

  // ============================================
  // 危険閾値
  // ============================================

  /// 危険閾値を取得 [μT]
  ///
  /// この値以上のノイズは「危険」と判定
  double get dangerThreshold {
    _ensureInitialized();
    return _prefs!.getDouble(_keyDangerThreshold) ??
        AppConstants.defaultDangerThreshold;
  }

  /// 危険閾値を設定 [μT]
  ///
  /// [value] 設定する危険閾値（安全閾値より大きい値）
  Future<void> setDangerThreshold(double value) async {
    _ensureInitialized();
    if (value < 0) {
      throw ArgumentError('危険閾値は0以上である必要があります: $value');
    }
    await _prefs!.setDouble(_keyDangerThreshold, value);
  }

  // ============================================
  // 計測間隔
  // ============================================

  /// 計測間隔を取得（秒）
  ///
  /// 自動計測モード時のポイント追加間隔
  double get measurementInterval {
    _ensureInitialized();
    return _prefs!.getDouble(_keyMeasurementInterval) ??
        AppConstants.defaultMeasurementInterval;
  }

  /// 計測間隔を設定（秒）
  ///
  /// [value] 設定する計測間隔（0.1秒以上）
  Future<void> setMeasurementInterval(double value) async {
    _ensureInitialized();
    if (value < 0.1) {
      throw ArgumentError('計測間隔は0.1秒以上である必要があります: $value');
    }
    await _prefs!.setDouble(_keyMeasurementInterval, value);
  }

  // ============================================
  // 自動計測モード
  // ============================================

  /// 自動計測モードが有効か
  bool get isAutoMeasurement {
    _ensureInitialized();
    return _prefs!.getBool(_keyAutoMeasurement) ?? false;
  }

  /// 自動計測モードを設定
  ///
  /// [enabled] true: 自動計測有効、false: 手動計測
  Future<void> setAutoMeasurement(bool enabled) async {
    _ensureInitialized();
    await _prefs!.setBool(_keyAutoMeasurement, enabled);
  }

  // ============================================
  // 地図タイプ
  // ============================================

  /// 地図タイプを取得
  ///
  /// 0: OpenStreetMap標準、1: 衛星写真
  int get mapType {
    _ensureInitialized();
    return _prefs!.getInt(_keyMapType) ?? 0;
  }

  /// 地図タイプを設定
  ///
  /// [type] 0: OpenStreetMap標準、1: 衛星写真
  Future<void> setMapType(int type) async {
    _ensureInitialized();
    await _prefs!.setInt(_keyMapType, type);
  }

  // ============================================
  // 一括操作
  // ============================================

  /// 全設定をデフォルト値にリセット
  Future<void> resetToDefaults() async {
    _ensureInitialized();
    await _prefs!.remove(_keyReferenceMag);
    await _prefs!.remove(_keySafeThreshold);
    await _prefs!.remove(_keyDangerThreshold);
    await _prefs!.remove(_keyMeasurementInterval);
    await _prefs!.remove(_keyAutoMeasurement);
    await _prefs!.remove(_keyMapType);
  }

  /// 現在の設定値を取得（デバッグ用）
  Map<String, dynamic> getCurrentSettings() {
    _ensureInitialized();
    return {
      'referenceMag': referenceMag,
      'safeThreshold': safeThreshold,
      'dangerThreshold': dangerThreshold,
      'measurementInterval': measurementInterval,
      'isAutoMeasurement': isAutoMeasurement,
      'mapType': mapType,
    };
  }

  @override
  String toString() {
    return 'SettingsService(${getCurrentSettings()})';
  }
}


