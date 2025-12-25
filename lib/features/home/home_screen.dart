/// MAG PLOTTER ホーム画面
///
/// ミッション一覧を表示し、各ミッションの管理を行う
/// スパイテック風UIでミッションカードを表示
library;

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/mission.dart';
import '../../data/repositories/mission_repository.dart';
import '../../data/repositories/measurement_point_repository.dart';
import '../mission/mission_card.dart';
import '../mission/mission_edit_dialog.dart';
import '../measurement/measurement_screen.dart';
import '../settings/settings_screen.dart';

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
  /// ミッションリポジトリ
  final MissionRepository _missionRepo = MissionRepository();

  /// 計測ポイントリポジトリ
  final MeasurementPointRepository _pointRepo = MeasurementPointRepository();

  /// ミッションリスト
  List<Mission> _missions = [];

  /// 各ミッションのポイント数
  Map<int, int> _pointCounts = {};

  /// 読み込み中フラグ
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMissions();
  }

  /// ミッション一覧を読み込み
  Future<void> _loadMissions() async {
    setState(() => _isLoading = true);

    try {
      final missions = await _missionRepo.getAll();
      final counts = <int, int>{};

      for (final mission in missions) {
        if (mission.id != null) {
          counts[mission.id!] = await _pointRepo.countByMissionId(mission.id!);
        }
      }

      if (mounted) {
        setState(() {
          _missions = missions;
          _pointCounts = counts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('ミッションの読み込みに失敗しました');
      }
    }
  }

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
                child: _isLoading
                    ? _buildLoading()
                    : _missions.isEmpty
                        ? _buildEmptyState()
                        : _buildMissionList(),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
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
                  '${_missions.length} mission${_missions.length != 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // 更新ボタン
          IconButton(
            onPressed: _loadMissions,
            icon: const Icon(
              Icons.refresh,
              color: AppColors.textSecondary,
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

  /// ローディング表示
  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.accentPrimary,
          ),
          SizedBox(height: 16),
          Text(
            'LOADING...',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: AppColors.textSecondary,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  /// ミッション一覧の構築
  Widget _buildMissionList() {
    return RefreshIndicator(
      onRefresh: _loadMissions,
      color: AppColors.accentPrimary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _missions.length,
        itemBuilder: (context, index) {
          final mission = _missions[index];
          return MissionCard(
            mission: mission,
            pointCount: _pointCounts[mission.id] ?? 0,
            onTap: () => _openMission(mission),
            onEdit: () => _editMission(mission),
            onDelete: () => _deleteMission(mission),
          );
        },
      ),
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
  Future<void> _createMission() async {
    final mission = await MissionEditDialog.show(context);
    if (mission != null) {
      try {
        await _missionRepo.insert(mission);
        await _loadMissions();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ミッションを作成しました'),
              backgroundColor: AppColors.statusSafe,
            ),
          );
        }
      } catch (e) {
        _showError('ミッションの作成に失敗しました');
      }
    }
  }

  /// ミッションを編集
  Future<void> _editMission(Mission mission) async {
    final updated = await MissionEditDialog.show(context, mission: mission);
    if (updated != null) {
      try {
        await _missionRepo.update(updated);
        await _loadMissions();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ミッションを更新しました'),
              backgroundColor: AppColors.statusSafe,
            ),
          );
        }
      } catch (e) {
        _showError('ミッションの更新に失敗しました');
      }
    }
  }

  /// ミッションを削除
  Future<void> _deleteMission(Mission mission) async {
    if (mission.id == null) return;

    try {
      await _missionRepo.delete(mission.id!);
      await _loadMissions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ミッションを削除しました'),
          ),
        );
      }
    } catch (e) {
      _showError('ミッションの削除に失敗しました');
    }
  }

  /// ミッションを開く（計測画面へ遷移）
  void _openMission(Mission mission) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MeasurementScreen(
          missionId: mission.id,
          missionName: mission.name,
        ),
      ),
    ).then((_) => _loadMissions());
  }

  /// 設定画面を開く
  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  /// エラーメッセージを表示
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.statusDanger,
        ),
      );
    }
  }
}
