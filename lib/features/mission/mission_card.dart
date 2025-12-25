/// MAG PLOTTER ミッションカード
///
/// ミッション一覧に表示するカードウィジェット
/// スパイテック風のデザインでミッション情報を表示
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/mission.dart';

/// ミッションカードウィジェット
///
/// ミッション情報をカード形式で表示
/// タップで計測画面へ、長押しでメニュー表示
class MissionCard extends StatelessWidget {
  /// ミッションデータ
  final Mission mission;

  /// 計測ポイント数
  final int pointCount;

  /// タップ時のコールバック
  final VoidCallback? onTap;

  /// 編集時のコールバック
  final VoidCallback? onEdit;

  /// 削除時のコールバック
  final VoidCallback? onDelete;

  const MissionCard({
    super.key,
    required this.mission,
    this.pointCount = 0,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showContextMenu(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: mission.isCompleted
                ? AppColors.statusSafe.withValues(alpha: 0.5)
                : AppColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentPrimary.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー
            _buildHeader(),

            // 区切り線
            Container(
              height: 1,
              color: AppColors.border.withValues(alpha: 0.5),
            ),

            // コンテンツ
            _buildContent(),

            // フッター
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  /// ヘッダーの構築
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // ステータスインジケーター
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: mission.isCompleted
                  ? AppColors.statusSafe
                  : AppColors.accentPrimary,
              boxShadow: [
                BoxShadow(
                  color: (mission.isCompleted
                          ? AppColors.statusSafe
                          : AppColors.accentPrimary)
                      .withValues(alpha: 0.5),
                  blurRadius: 8,
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // ミッション名
          Expanded(
            child: Text(
              mission.name.toUpperCase(),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                letterSpacing: 1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // ポイント数バッジ
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accentPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.accentPrimary.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              '$pointCount pts',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: AppColors.accentPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// コンテンツの構築
  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 場所
          if (mission.location.isNotEmpty) ...[
            _buildInfoRow(Icons.location_on, mission.location),
            const SizedBox(height: 8),
          ],

          // 担当者
          if (mission.assignee.isNotEmpty) ...[
            _buildInfoRow(Icons.person, mission.assignee),
            const SizedBox(height: 8),
          ],

          // 閾値設定
          Row(
            children: [
              _buildThresholdChip(
                'REF',
                '${mission.referenceMag.toStringAsFixed(0)}μT',
                AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              _buildThresholdChip(
                'SAFE',
                '${mission.safeThreshold.toStringAsFixed(0)}μT',
                AppColors.statusSafe,
              ),
              const SizedBox(width: 8),
              _buildThresholdChip(
                'DANGER',
                '${mission.dangerThreshold.toStringAsFixed(0)}μT',
                AppColors.statusDanger,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 情報行の構築
  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// 閾値チップの構築
  Widget _buildThresholdChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 8,
              color: color.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// フッターの構築
  Widget _buildFooter() {
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.access_time,
            size: 12,
            color: AppColors.textHint,
          ),
          const SizedBox(width: 4),
          Text(
            dateFormat.format(mission.updatedAt),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              color: AppColors.textHint,
            ),
          ),
          const Spacer(),
          if (mission.isCompleted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.statusSafe.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'COMPLETED',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: AppColors.statusSafe,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// コンテキストメニューを表示
  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ハンドル
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ミッション名
            Text(
              mission.name,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.accentPrimary,
              ),
            ),

            const SizedBox(height: 16),

            // 編集ボタン
            ListTile(
              leading: const Icon(Icons.edit, color: AppColors.accentPrimary),
              title: const Text('編集'),
              onTap: () {
                Navigator.pop(context);
                onEdit?.call();
              },
            ),

            // 削除ボタン
            ListTile(
              leading: const Icon(Icons.delete, color: AppColors.statusDanger),
              title: const Text(
                '削除',
                style: TextStyle(color: AppColors.statusDanger),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context);
              },
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// 削除確認ダイアログ
  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        title: const Text(
          '削除確認',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          '「${mission.name}」を削除しますか？\nこの操作は取り消せません。',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete?.call();
            },
            child: const Text(
              '削除',
              style: TextStyle(color: AppColors.statusDanger),
            ),
          ),
        ],
      ),
    );
  }
}

