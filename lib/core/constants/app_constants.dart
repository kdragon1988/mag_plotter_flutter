/// MAG PLOTTER 定数定義
///
/// アプリ全体で使用する定数値
/// 磁場計測の閾値、デフォルト設定など
library;

/// アプリケーション定数
class AppConstants {
  AppConstants._();

  // ============================================
  // アプリ情報
  // ============================================

  /// アプリ名
  static const String appName = 'VISIONOID MAG PLOTTER';

  /// アプリバージョン
  static const String appVersion = '0.1.0';

  /// 会社名
  static const String companyName = 'VISIONOID Inc.';

  // ============================================
  // 磁場計測デフォルト値
  // ============================================

  /// 基準磁場値（日本平均）[μT]
  static const double defaultReferenceMag = 46.0;

  /// 安全閾値 [μT]
  static const double defaultSafeThreshold = 10.0;

  /// 危険閾値 [μT]
  static const double defaultDangerThreshold = 50.0;

  /// 計測間隔（秒）
  static const double defaultMeasurementInterval = 1.0;

  // ============================================
  // マップ設定
  // ============================================

  /// デフォルト緯度（東京）
  static const double defaultLatitude = 35.6812;

  /// デフォルト経度（東京）
  static const double defaultLongitude = 139.7671;

  /// デフォルトズームレベル
  static const double defaultZoom = 15.0;

  /// 最小ズームレベル
  static const double minZoom = 3.0;

  /// 最大ズームレベル
  static const double maxZoom = 19.0;

  // ============================================
  // UI設定
  // ============================================

  /// スプラッシュ画面表示時間（ミリ秒）
  static const int splashDuration = 2000;

  /// アニメーション時間（ミリ秒）
  static const int animationDuration = 300;

  /// デバウンス時間（ミリ秒）
  static const int debounceDuration = 500;

  // ============================================
  // 計測ポイントサイズ
  // ============================================

  /// ポイント半径（ピクセル）
  static const double pointRadius = 12.0;

  /// ポイントボーダー幅
  static const double pointBorderWidth = 2.0;
}

