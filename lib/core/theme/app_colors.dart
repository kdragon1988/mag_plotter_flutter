/// MAG PLOTTER カラー定義
///
/// スパイテック風（ミッションインポッシブル）ダークテーマのカラーパレット
/// Android版と統一されたデザインシステム
library;

import 'package:flutter/material.dart';

/// アプリ全体で使用するカラー定義
///
/// 命名規則:
/// - background*: 背景色
/// - accent*: アクセントカラー
/// - status*: ステータス表示用
/// - text*: テキストカラー
class AppColors {
  AppColors._();

  // ============================================
  // 背景カラー
  // ============================================

  /// メイン背景（ほぼ黒）
  static const Color backgroundPrimary = Color(0xFF0A0A0F);

  /// セカンダリ背景（ダークネイビー）
  static const Color backgroundSecondary = Color(0xFF1A1A2E);

  /// カード背景
  static const Color backgroundCard = Color(0xFF16213E);

  /// サーフェス（ダイアログなど）
  static const Color surface = Color(0xFF1E2746);

  // ============================================
  // アクセントカラー
  // ============================================

  /// プライマリアクセント（シアン）
  static const Color accentPrimary = Color(0xFF00F5FF);

  /// セカンダリアクセント（シアン暗め）
  static const Color accentSecondary = Color(0xFF00B4D8);

  /// オレンジアクセント
  static const Color accentOrange = Color(0xFFFF6B35);

  // ============================================
  // ステータスカラー
  // ============================================

  /// 安全（緑）
  static const Color statusSafe = Color(0xFF00FF88);

  /// 警告（黄）
  static const Color statusWarning = Color(0xFFFFD93D);

  /// 危険（ネオンレッド）
  static const Color statusDanger = Color(0xFFFF0055);

  // ============================================
  // テキストカラー
  // ============================================

  /// プライマリテキスト（白）
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// セカンダリテキスト（グレー）
  static const Color textSecondary = Color(0xFFB0B0B0);

  /// ヒントテキスト（暗めグレー）
  static const Color textHint = Color(0xFF6B7280);

  /// アクセントテキスト（シアン）
  static const Color textAccent = Color(0xFF00F5FF);

  // ============================================
  // ボーダー・ディバイダー
  // ============================================

  /// デフォルトボーダー
  static const Color border = Color(0xFF2A2A4A);

  /// アクセントボーダー
  static const Color borderAccent = Color(0xFF00F5FF);

  // ============================================
  // グラデーション
  // ============================================

  /// 背景グラデーション
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundPrimary, backgroundSecondary],
  );

  /// アクセントグラデーション
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentPrimary, accentSecondary],
  );

  // ============================================
  // マップレイヤーカラー
  // ============================================

  /// DID（人口集中地区）- オレンジ
  static const Color layerDid = Color(0x4DFF9800);

  /// 空港制限区域 - 赤
  static const Color layerAirport = Color(0x4DF44336);

  /// 飛行禁止区域 - 青
  static const Color layerNoFly = Color(0x4D2196F3);

  // ============================================
  // 描画色（作図機能用）
  // ============================================

  /// 描画色：オレンジ
  static const Color drawingOrange = Color(0xFFFF9800);

  /// 描画色：ブルー
  static const Color drawingBlue = Color(0xFF2196F3);

  /// 描画色：グリーン
  static const Color drawingGreen = Color(0xFF4CAF50);

  /// 描画色：レッド
  static const Color drawingRed = Color(0xFFF44336);

  /// 描画色：パープル
  static const Color drawingPurple = Color(0xFF9C27B0);

  /// 描画色：イエロー
  static const Color drawingYellow = Color(0xFFFFEB3B);

  /// 描画色リスト
  static const List<Color> drawingColors = [
    drawingOrange,
    drawingBlue,
    drawingGreen,
    drawingRed,
    drawingPurple,
    drawingYellow,
  ];
}

