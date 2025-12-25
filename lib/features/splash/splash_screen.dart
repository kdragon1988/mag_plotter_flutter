/// MAG PLOTTER スプラッシュ画面
///
/// アプリ起動時に表示されるスプラッシュ画面
/// スパイテック風のアニメーション付きロゴ表示
library;

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../home/home_screen.dart';

/// スプラッシュ画面
///
/// 起動時にロゴとアプリ名をアニメーション表示し、
/// 一定時間後にホーム画面へ遷移する
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  /// アニメーションコントローラー
  late AnimationController _animationController;

  /// フェードインアニメーション
  late Animation<double> _fadeAnimation;

  /// スケールアニメーション
  late Animation<double> _scaleAnimation;

  /// グローアニメーション
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _navigateToHome();
  }

  /// アニメーションの初期化
  void _initAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // フェードイン（0.0 → 1.0）
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    // スケール（0.8 → 1.0）
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    // グロー効果（0.0 → 1.0 → 0.5 ループ）
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
      ),
    );

    _animationController.forward();
  }

  /// ホーム画面への遷移
  Future<void> _navigateToHome() async {
    await Future.delayed(
      const Duration(milliseconds: AppConstants.splashDuration),
    );

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Stack(
          children: [
            // グリッド背景
            _buildGridBackground(),

            // メインコンテンツ
            Center(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ロゴアイコン
                          _buildLogo(),

                          const SizedBox(height: 32),

                          // アプリ名
                          _buildAppName(),

                          const SizedBox(height: 8),

                          // サブタイトル
                          _buildSubtitle(),

                          const SizedBox(height: 48),

                          // ローディングインジケーター
                          _buildLoadingIndicator(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // バージョン情報
            _buildVersionInfo(),
          ],
        ),
      ),
    );
  }

  /// グリッド背景の構築
  Widget _buildGridBackground() {
    return CustomPaint(
      painter: _GridPainter(),
      size: Size.infinite,
    );
  }

  /// ロゴの構築
  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.accentPrimary,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentPrimary.withValues(
                  alpha: 0.3 + (_glowAnimation.value * 0.4),
                ),
                blurRadius: 20 + (_glowAnimation.value * 20),
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.radar,
              size: 64,
              color: AppColors.accentPrimary,
            ),
          ),
        );
      },
    );
  }

  /// アプリ名の構築
  Widget _buildAppName() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [AppColors.accentPrimary, AppColors.accentSecondary],
      ).createShader(bounds),
      child: const Text(
        'MAG PLOTTER',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 4,
        ),
      ),
    );
  }

  /// サブタイトルの構築
  Widget _buildSubtitle() {
    return const Text(
      'VISIONOID DRONE SHOW SUPPORT',
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        color: AppColors.textSecondary,
        letterSpacing: 2,
      ),
    );
  }

  /// ローディングインジケーターの構築
  Widget _buildLoadingIndicator() {
    return SizedBox(
      width: 200,
      child: LinearProgressIndicator(
        backgroundColor: AppColors.backgroundCard,
        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentPrimary),
        minHeight: 2,
      ),
    );
  }

  /// バージョン情報の構築
  Widget _buildVersionInfo() {
    return Positioned(
      bottom: 32,
      left: 0,
      right: 0,
      child: Center(
        child: Text(
          'v${AppConstants.appVersion}',
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: AppColors.textHint,
          ),
        ),
      ),
    );
  }
}

/// グリッド背景を描画するカスタムペインター
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.3)
      ..strokeWidth = 0.5;

    const gridSize = 40.0;

    // 縦線
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // 横線
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

