/// MAG PLOTTER 描画ツールバー
///
/// 図形描画用のコンパクトなツールバーウィジェット
/// モード選択、色選択、Undo、保存などの操作を提供
library;

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'drawing_mode.dart';
import 'drawing_controller.dart';

/// 描画ツールバーウィジェット（コンパクト版）
class DrawingToolbar extends StatelessWidget {
  /// 描画コントローラー
  final DrawingController controller;

  /// 保存コールバック
  final VoidCallback? onSave;

  /// 閉じるコールバック
  final VoidCallback? onClose;

  const DrawingToolbar({
    super.key,
    required this.controller,
    this.onSave,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // モード選択と閉じるボタン
              _buildModeRow(),

              if (controller.isDrawing) ...[
                const SizedBox(height: 4),

                // 色選択 + サマリー
                Row(
                  children: [
                    // 色選択
                    Expanded(child: _buildColorRow()),
                    const SizedBox(width: 8),
                    // サマリー
                    Expanded(child: _buildSummary()),
                  ],
                ),

                const SizedBox(height: 4),

                // アクションボタン
                _buildActionRow(),
              ],
            ],
          ),
        );
      },
    );
  }

  /// モード選択行
  Widget _buildModeRow() {
    return Row(
      children: [
        // モードボタン（コンパクト）
        _buildModeChip(DrawingMode.polygon, Icons.hexagon_outlined, 'POLY'),
        const SizedBox(width: 3),
        _buildModeChip(DrawingMode.polyline, Icons.timeline, 'LINE'),
        const SizedBox(width: 3),
        _buildModeChip(DrawingMode.circle, Icons.circle_outlined, 'CIRCLE'),

        const Spacer(),

        // 閉じるボタン
        GestureDetector(
          onTap: onClose,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(
              Icons.close,
              color: AppColors.textSecondary,
              size: 16,
            ),
          ),
        ),
      ],
    );
  }

  /// モードチップ
  Widget _buildModeChip(DrawingMode mode, IconData icon, String label) {
    final isSelected = controller.mode == mode;

    return GestureDetector(
      onTap: () => controller.setMode(isSelected ? DrawingMode.none : mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentPrimary.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? AppColors.accentPrimary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color:
                  isSelected ? AppColors.accentPrimary : AppColors.textSecondary,
              size: 14,
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? AppColors.accentPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 色選択行
  Widget _buildColorRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: AppColors.drawingColors.map((color) {
        final isSelected = controller.selectedColor.value == color.value;
        return GestureDetector(
          onTap: () => controller.setColor(color),
          child: Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 2,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// サマリー情報（面積/距離のみ）
  Widget _buildSummary() {
    String? summaryText;

    switch (controller.mode) {
      case DrawingMode.polygon:
        if (controller.points.length >= 3) {
          final area = controller.calculatePolygonArea();
          summaryText = controller.formatArea(area);
        } else {
          summaryText = '頂点: ${controller.points.length}/3+';
        }
        break;

      case DrawingMode.polyline:
        if (controller.points.length >= 2) {
          final distance = controller.calculateTotalDistance();
          summaryText = controller.formatDistance(distance);
        } else {
          summaryText = '頂点: ${controller.points.length}/2+';
        }
        break;

      case DrawingMode.circle:
        if (controller.circleCenter != null && controller.circleRadius > 0) {
          final area = controller.calculateCircleArea();
          summaryText = controller.formatArea(area);
        } else if (controller.circleCenter != null) {
          summaryText = '半径設定';
        } else {
          summaryText = '中心設定';
        }
        break;

      case DrawingMode.none:
        break;
    }

    if (summaryText == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        summaryText,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: AppColors.accentPrimary,
        ),
      ),
    );
  }

  /// アクションボタン行
  Widget _buildActionRow() {
    return Row(
      children: [
        // Undoボタン
        Expanded(
          child: _buildActionButton(
            icon: Icons.undo,
            label: 'UNDO',
            onTap: controller.hasPoints ? controller.undo : null,
          ),
        ),

        const SizedBox(width: 4),

        // クリアボタン
        Expanded(
          child: _buildActionButton(
            icon: Icons.clear,
            label: 'CLEAR',
            onTap: controller.hasPoints ? controller.clear : null,
          ),
        ),

        const SizedBox(width: 4),

        // 保存ボタン
        Expanded(
          child: _buildActionButton(
            icon: Icons.save,
            label: 'SAVE',
            onTap: controller.canComplete ? onSave : null,
            isPrimary: true,
          ),
        ),
      ],
    );
  }

  /// アクションボタン
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    bool isPrimary = false,
  }) {
    final isEnabled = onTap != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: isPrimary && isEnabled
              ? AppColors.accentPrimary
              : AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isEnabled ? AppColors.border : AppColors.border.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 12,
              color: isPrimary && isEnabled
                  ? AppColors.backgroundPrimary
                  : isEnabled
                      ? AppColors.textPrimary
                      : AppColors.textHint,
            ),
            const SizedBox(width: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: isPrimary && isEnabled
                    ? AppColors.backgroundPrimary
                    : isEnabled
                        ? AppColors.textPrimary
                        : AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
