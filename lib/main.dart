/// VISIONOID MAG PLOTTER - Flutter版
///
/// ドローンショー現場の磁場環境を調査するためのクロスプラットフォームアプリケーション
/// iOS/Android両対応
///
/// 主な機能:
/// - ミッション管理
/// - リアルタイム磁場計測
/// - ヒートマップ表示
/// - 地図作図機能
/// - GeoJSONレイヤー表示
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/splash_screen.dart';

/// アプリケーションのエントリーポイント
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // システムUIの設定（ステータスバー透明化）
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0A0F),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // 画面の向きを縦固定
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MagPlotterApp());
}

/// MAG PLOTTERアプリケーションのルートウィジェット
///
/// テーマ設定とルーティングを管理
class MagPlotterApp extends StatelessWidget {
  const MagPlotterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // アプリ設定
      title: 'MAG PLOTTER',
      debugShowCheckedModeBanner: false,

      // テーマ設定
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,

      // 初期画面
      home: const SplashScreen(),
    );
  }
}
