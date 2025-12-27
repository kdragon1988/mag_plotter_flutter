/// コンパスウィジェット
/// 
/// 現在の方位と地図の北を表示するコンパクトなコンパスUI。
/// 磁気センサーから取得した方位をリアルタイムで表示。
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// コンパスウィジェット
/// 
/// [heading] 現在の方位（度、0-360、0=北）
/// [mapRotation] 地図の回転角度（度）
/// [onTap] タップ時のコールバック（北にリセット等）
class CompassWidget extends StatelessWidget {
  final double heading;
  final double mapRotation;
  final VoidCallback? onTap;
  final double size;

  const CompassWidget({
    super.key,
    required this.heading,
    this.mapRotation = 0,
    this.onTap,
    this.size = 56,
  });

  /// 方位の方角名を取得（8方位）
  String get _directionName {
    final h = heading;
    if (h >= 337.5 || h < 22.5) return 'N';
    if (h >= 22.5 && h < 67.5) return 'NE';
    if (h >= 67.5 && h < 112.5) return 'E';
    if (h >= 112.5 && h < 157.5) return 'SE';
    if (h >= 157.5 && h < 202.5) return 'S';
    if (h >= 202.5 && h < 247.5) return 'SW';
    if (h >= 247.5 && h < 292.5) return 'W';
    if (h >= 292.5 && h < 337.5) return 'NW';
    return 'N';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.backgroundCard.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(size / 2),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // コンパスリング（地図の北を示す）
            Transform.rotate(
              angle: -mapRotation * math.pi / 180,
              child: CustomPaint(
                size: Size(size - 8, size - 8),
                painter: _CompassRingPainter(),
              ),
            ),
            
            // 方位矢印（現在の方位を示す）
            Transform.rotate(
              angle: -heading * math.pi / 180,
              child: CustomPaint(
                size: Size(size - 16, size - 16),
                painter: _CompassNeedlePainter(),
              ),
            ),
            
            // 方位表示
            Positioned(
              bottom: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.backgroundPrimary.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${heading.toStringAsFixed(0)}°',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// コンパスリングペインター（N/E/S/Wマーカー）
class _CompassRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // 北マーカー（赤）
    _drawDirectionMarker(canvas, center, radius, 0, 'N', Colors.red);
    
    // 東マーカー
    _drawDirectionMarker(canvas, center, radius, 90, 'E', AppColors.textHint);
    
    // 南マーカー
    _drawDirectionMarker(canvas, center, radius, 180, 'S', AppColors.textHint);
    
    // 西マーカー
    _drawDirectionMarker(canvas, center, radius, 270, 'W', AppColors.textHint);
  }

  void _drawDirectionMarker(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
    String label,
    Color color,
  ) {
    final rad = angle * math.pi / 180;
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    
    final x = center.dx + (radius - 8) * math.sin(rad) - textPainter.width / 2;
    final y = center.dy - (radius - 8) * math.cos(rad) - textPainter.height / 2;
    
    textPainter.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// コンパス針ペインター
class _CompassNeedlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // 北を指す三角形（赤）
    final northPath = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx - 4, center.dy)
      ..lineTo(center.dx + 4, center.dy)
      ..close();
    
    canvas.drawPath(
      northPath,
      Paint()
        ..color = Colors.red
        ..style = PaintingStyle.fill,
    );

    // 南を指す三角形（グレー）
    final southPath = Path()
      ..moveTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - 4, center.dy)
      ..lineTo(center.dx + 4, center.dy)
      ..close();
    
    canvas.drawPath(
      southPath,
      Paint()
        ..color = AppColors.textHint
        ..style = PaintingStyle.fill,
    );

    // 中心の円
    canvas.drawCircle(
      center,
      3,
      Paint()..color = AppColors.textSecondary,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// コンパクトな方位表示ウィジェット（テキストのみ）
class CompactHeadingWidget extends StatelessWidget {
  final double heading;
  
  const CompactHeadingWidget({
    super.key,
    required this.heading,
  });

  String get _directionName {
    final h = heading;
    if (h >= 337.5 || h < 22.5) return 'N';
    if (h >= 22.5 && h < 67.5) return 'NE';
    if (h >= 67.5 && h < 112.5) return 'E';
    if (h >= 112.5 && h < 157.5) return 'SE';
    if (h >= 157.5 && h < 202.5) return 'S';
    if (h >= 202.5 && h < 247.5) return 'SW';
    if (h >= 247.5 && h < 292.5) return 'W';
    if (h >= 292.5 && h < 337.5) return 'NW';
    return 'N';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 方角アイコン
          Transform.rotate(
            angle: -heading * math.pi / 180,
            child: const Icon(
              Icons.navigation,
              color: Colors.red,
              size: 16,
            ),
          ),
          const SizedBox(width: 4),
          // 方位テキスト
          Text(
            '${heading.toStringAsFixed(0)}° $_directionName',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

