/// MAG PLOTTER 計測ポイントマーカー
///
/// 地図上に表示する計測ポイントのマーカーウィジェット
/// ノイズ値に応じて色分け（緑・黄・赤）
library;

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';

/// 計測ポイントマーカーウィジェット
///
/// ノイズ値に基づいてヒートマップ色で表示
class MeasurementMarker extends StatelessWidget {
  /// ノイズ値 [μT]
  final double noise;

  /// 安全閾値 [μT]
  final double safeThreshold;

  /// 危険閾値 [μT]
  final double dangerThreshold;

  /// マーカーサイズ
  final double size;

  /// タップ時のコールバック
  final VoidCallback? onTap;

  /// 選択状態
  final bool isSelected;

  const MeasurementMarker({
    super.key,
    required this.noise,
    this.safeThreshold = AppConstants.defaultSafeThreshold,
    this.dangerThreshold = AppConstants.defaultDangerThreshold,
    this.size = 24,
    this.onTap,
    this.isSelected = false,
  });

  /// ノイズ値に基づいて色を取得
  Color get color {
    if (noise < safeThreshold) {
      return AppColors.statusSafe;
    } else if (noise < dangerThreshold) {
      return AppColors.statusWarning;
    } else {
      return AppColors.statusDanger;
    }
  }

  /// グラデーション色を取得（ヒートマップ用）
  Color get gradientColor {
    // 0 → 緑, safeThreshold → 黄, dangerThreshold+ → 赤
    if (noise < safeThreshold) {
      // 緑 → 黄のグラデーション
      final t = noise / safeThreshold;
      return Color.lerp(AppColors.statusSafe, AppColors.statusWarning, t)!;
    } else if (noise < dangerThreshold) {
      // 黄 → 赤のグラデーション
      final t = (noise - safeThreshold) / (dangerThreshold - safeThreshold);
      return Color.lerp(AppColors.statusWarning, AppColors.statusDanger, t)!;
    } else {
      return AppColors.statusDanger;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: gradientColor,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.8),
            width: isSelected ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColor.withValues(alpha: 0.6),
              blurRadius: isSelected ? 12 : 8,
              spreadRadius: isSelected ? 4 : 2,
            ),
          ],
        ),
        child: isSelected
            ? Center(
                child: Container(
                  width: size * 0.4,
                  height: size * 0.4,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

/// 計測ポイント情報ポップアップ
///
/// マーカータップ時に表示する詳細情報
class MeasurementInfoPopup extends StatelessWidget {
  /// 磁場値 [μT]
  final double magField;

  /// ノイズ値 [μT]
  final double noise;

  /// タイムスタンプ
  final DateTime timestamp;

  /// 閉じるコールバック
  final VoidCallback? onClose;

  const MeasurementInfoPopup({
    super.key,
    required this.magField,
    required this.noise,
    required this.timestamp,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final color = noise < AppConstants.defaultSafeThreshold
        ? AppColors.statusSafe
        : noise < AppConstants.defaultDangerThreshold
            ? AppColors.statusWarning
            : AppColors.statusDanger;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                noise < AppConstants.defaultSafeThreshold
                    ? 'SAFE'
                    : noise < AppConstants.defaultDangerThreshold
                        ? 'WARNING'
                        : 'DANGER',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              if (onClose != null)
                GestureDetector(
                  onTap: onClose,
                  child: const Icon(
                    Icons.close,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // データ
          _buildDataRow('MAG', '${magField.toStringAsFixed(1)} μT'),
          const SizedBox(height: 4),
          _buildDataRow('NOISE', '${noise.toStringAsFixed(1)} μT', color: color),
          const SizedBox(height: 4),
          _buildDataRow(
            'TIME',
            '${timestamp.hour.toString().padLeft(2, '0')}:'
                '${timestamp.minute.toString().padLeft(2, '0')}:'
                '${timestamp.second.toString().padLeft(2, '0')}',
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

