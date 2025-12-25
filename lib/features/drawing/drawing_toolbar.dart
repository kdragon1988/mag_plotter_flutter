/// MAG PLOTTER 描画ツールバー
///
/// 図形描画用のツールバーウィジェット
/// モード選択、色選択、Undo、保存などの操作を提供
library;

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'drawing_mode.dart';
import 'drawing_controller.dart';

/// 描画ツールバーウィジェット
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
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ヘッダー
              _buildHeader(),

              const Divider(color: AppColors.border, height: 24),

              // モード選択
              _buildModeSelector(),

              if (controller.isDrawing) ...[
                const SizedBox(height: 16),

                // 色選択
                _buildColorSelector(),

                const SizedBox(height: 16),

                // 計測値表示
                _buildMeasurements(),

                const SizedBox(height: 16),

                // アクションボタン
                _buildActions(),
              ],
            ],
          ),
        );
      },
    );
  }

  /// ヘッダーの構築
  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(
          Icons.draw,
          color: AppColors.accentPrimary,
          size: 20,
        ),
        const SizedBox(width: 8),
        const Text(
          'DRAWING',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.accentPrimary,
            letterSpacing: 2,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: onClose,
          icon: const Icon(
            Icons.close,
            color: AppColors.textSecondary,
            size: 20,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  /// モード選択の構築
  Widget _buildModeSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildModeButton(DrawingMode.polygon, Icons.hexagon_outlined),
        _buildModeButton(DrawingMode.polyline, Icons.timeline),
        _buildModeButton(DrawingMode.circle, Icons.circle_outlined),
      ],
    );
  }

  /// モードボタンの構築
  Widget _buildModeButton(DrawingMode mode, IconData icon) {
    final isSelected = controller.mode == mode;

    return GestureDetector(
      onTap: () => controller.setMode(isSelected ? DrawingMode.none : mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentPrimary.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.accentPrimary : AppColors.border,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.accentPrimary : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              mode.shortName,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.accentPrimary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 色選択の構築
  Widget _buildColorSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: AppColors.drawingColors.map((color) {
        final isSelected = controller.selectedColor.value == color.value;
        return GestureDetector(
          onTap: () => controller.setColor(color),
          child: Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 3,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 計測値表示の構築
  Widget _buildMeasurements() {
    String? measurementText;

    switch (controller.mode) {
      case DrawingMode.polygon:
        if (controller.points.length >= 3) {
          final area = controller.calculatePolygonArea();
          final perimeter = controller.calculateTotalDistance();
          measurementText =
              '面積: ${controller.formatArea(area)}\n周囲長: ${controller.formatDistance(perimeter)}';
        } else {
          measurementText = 'タップで頂点を追加 (${controller.points.length}/3+)';
        }
        break;

      case DrawingMode.polyline:
        if (controller.points.length >= 2) {
          final distance = controller.calculateTotalDistance();
          measurementText = '距離: ${controller.formatDistance(distance)}';
        } else {
          measurementText = 'タップで頂点を追加 (${controller.points.length}/2+)';
        }
        break;

      case DrawingMode.circle:
        if (controller.circleCenter != null && controller.circleRadius > 0) {
          final area = controller.calculateCircleArea();
          measurementText =
              '半径: ${controller.formatDistance(controller.circleRadius)}\n面積: ${controller.formatArea(area)}';
        } else if (controller.circleCenter != null) {
          measurementText = 'ドラッグで半径を設定';
        } else {
          measurementText = 'タップで中心を設定';
        }
        break;

      case DrawingMode.none:
        break;
    }

    if (measurementText == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        measurementText,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  /// アクションボタンの構築
  Widget _buildActions() {
    return Row(
      children: [
        // Undoボタン
        Expanded(
          child: OutlinedButton.icon(
            onPressed: controller.hasPoints ? controller.undo : null,
            icon: const Icon(Icons.undo, size: 18),
            label: const Text('UNDO'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // クリアボタン
        Expanded(
          child: OutlinedButton.icon(
            onPressed: controller.hasPoints ? controller.clear : null,
            icon: const Icon(Icons.clear, size: 18),
            label: const Text('CLEAR'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // 保存ボタン
        Expanded(
          child: ElevatedButton.icon(
            onPressed: controller.canComplete ? onSave : null,
            icon: const Icon(Icons.save, size: 18),
            label: const Text('SAVE'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}

