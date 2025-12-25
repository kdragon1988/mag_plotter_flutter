/// MAG PLOTTER ホーム画面
///
/// ミッション一覧を表示し、各ミッションの管理を行う
/// スパイテック風UIでミッションカードを表示
library;

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../measurement/measurement_screen.dart';

/// ホーム画面（ミッション一覧）
///
/// ミッションの作成、編集、削除、選択を行う
/// 選択したミッションで計測画面へ遷移
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ヘッダー
              _buildHeader(),

              // ミッション一覧
              Expanded(
                child: _buildMissionList(),
              ),
            ],
          ),
        ),
      ),

      // 新規ミッション作成ボタン
      floatingActionButton: _buildFab(),
    );
  }

  /// ヘッダーの構築
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary.withValues(alpha: 0.8),
        border: const Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          // ロゴ
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accentPrimary, width: 2),
            ),
            child: const Icon(
              Icons.radar,
              color: AppColors.accentPrimary,
              size: 24,
            ),
          ),

          const SizedBox(width: 12),

          // タイトル
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MISSIONS',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentPrimary,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'Select or create a mission',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // 設定ボタン
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(
              Icons.settings,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// ミッション一覧の構築
  Widget _buildMissionList() {
    // TODO: 実際のミッションデータを読み込む
    // 仮のデータで表示

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 空の状態メッセージ
        _buildEmptyState(),
      ],
    );
  }

  /// 空の状態の表示
  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 100),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // アイコン
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.border,
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.folder_open,
              size: 48,
              color: AppColors.textHint,
            ),
          ),

          const SizedBox(height: 24),

          // メッセージ
          const Text(
            'NO MISSIONS YET',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
              letterSpacing: 2,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Create your first mission to start\nmeasuring magnetic fields',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textHint,
            ),
          ),

          const SizedBox(height: 32),

          // 作成ボタン
          OutlinedButton.icon(
            onPressed: _createMission,
            icon: const Icon(Icons.add),
            label: const Text('CREATE MISSION'),
          ),
        ],
      ),
    );
  }

  /// FABの構築
  Widget _buildFab() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.accentPrimary.withValues(alpha: 0.4),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: _createMission,
        child: const Icon(Icons.add),
      ),
    );
  }

  /// 新規ミッション作成
  void _createMission() {
    // 計測画面へ直接遷移（デモ用）
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const MeasurementScreen(
          missionName: 'NEW MISSION',
        ),
      ),
    );
  }

  /// 設定画面を開く
  void _openSettings() {
    // TODO: 設定画面へ遷移
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('設定画面は開発中です'),
      ),
    );
  }
}

