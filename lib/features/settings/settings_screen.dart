/// MAG PLOTTER 設定画面
///
/// アプリの各種設定を行う画面
/// 磁場計測の閾値、計測間隔、自動計測モードの設定
library;

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../services/settings_service.dart';

/// 設定画面
///
/// 磁場計測に関する各種設定を行う
/// スパイテック風UIでデザイン
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// 設定サービス
  final SettingsService _settingsService = SettingsService();

  /// 各設定値のコントローラー
  late TextEditingController _referenceMagController;
  late TextEditingController _safeThresholdController;
  late TextEditingController _dangerThresholdController;
  late TextEditingController _intervalController;

  /// 自動計測モードフラグ
  bool _isAutoMeasurement = false;

  /// 変更があったかどうか
  bool _hasChanges = false;

  /// 保存中フラグ
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  /// コントローラーを初期化
  void _initializeControllers() {
    _referenceMagController = TextEditingController(
      text: _settingsService.referenceMag.toStringAsFixed(1),
    );
    _safeThresholdController = TextEditingController(
      text: _settingsService.safeThreshold.toStringAsFixed(1),
    );
    _dangerThresholdController = TextEditingController(
      text: _settingsService.dangerThreshold.toStringAsFixed(1),
    );
    _intervalController = TextEditingController(
      text: _settingsService.measurementInterval.toStringAsFixed(1),
    );
    _isAutoMeasurement = _settingsService.isAutoMeasurement;

    // 変更検知用リスナー
    _referenceMagController.addListener(_onChanged);
    _safeThresholdController.addListener(_onChanged);
    _dangerThresholdController.addListener(_onChanged);
    _intervalController.addListener(_onChanged);
  }

  /// 変更検知
  void _onChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  void dispose() {
    _referenceMagController.dispose();
    _safeThresholdController.dispose();
    _dangerThresholdController.dispose();
    _intervalController.dispose();
    super.dispose();
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

              // 設定項目リスト
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // 磁場計測セクション
                    _buildSectionHeader('MAGNETIC FIELD'),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      icon: Icons.adjust,
                      title: '基準磁場値',
                      subtitle: '日本の平均値は約46μT',
                      child: _buildNumberInput(
                        controller: _referenceMagController,
                        unit: 'μT',
                        min: 0,
                        max: 100,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 閾値セクション
                    _buildSectionHeader('THRESHOLDS'),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      icon: Icons.check_circle_outline,
                      title: '安全閾値',
                      subtitle: 'この値未満は安全（緑）と判定',
                      child: _buildNumberInput(
                        controller: _safeThresholdController,
                        unit: 'μT',
                        min: 0,
                        max: 100,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildSettingCard(
                      icon: Icons.warning_amber_outlined,
                      title: '危険閾値',
                      subtitle: 'この値以上は危険（赤）と判定',
                      child: _buildNumberInput(
                        controller: _dangerThresholdController,
                        unit: 'μT',
                        min: 0,
                        max: 200,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 計測設定セクション
                    _buildSectionHeader('MEASUREMENT'),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      icon: Icons.timer_outlined,
                      title: '計測間隔',
                      subtitle: '自動計測時のポイント追加間隔',
                      child: _buildNumberInput(
                        controller: _intervalController,
                        unit: '秒',
                        min: 0.5,
                        max: 60,
                        step: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildSettingCard(
                      icon: Icons.auto_mode,
                      title: '自動計測モード',
                      subtitle: 'ONにすると設定間隔で自動的にポイント追加',
                      child: _buildSwitch(
                        value: _isAutoMeasurement,
                        onChanged: (value) {
                          setState(() {
                            _isAutoMeasurement = value;
                            _hasChanges = true;
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 閾値プレビュー
                    _buildThresholdPreview(),

                    const SizedBox(height: 24),

                    // リセットボタン
                    _buildResetButton(),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
          // 戻るボタン
          IconButton(
            onPressed: () => _onBack(),
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          ),

          const SizedBox(width: 8),

          // タイトル
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SETTINGS',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentPrimary,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'Configure measurement parameters',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // 保存ボタン
          _buildSaveButton(),
        ],
      ),
    );
  }

  /// 保存ボタン
  Widget _buildSaveButton() {
    return AnimatedOpacity(
      opacity: _hasChanges ? 1.0 : 0.5,
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: _hasChanges
              ? [
                  BoxShadow(
                    color: AppColors.accentPrimary.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: ElevatedButton.icon(
          onPressed: _hasChanges && !_isSaving ? _saveSettings : null,
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.backgroundPrimary,
                  ),
                )
              : const Icon(Icons.save, size: 18),
          label: Text(_isSaving ? 'SAVING...' : 'SAVE'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentPrimary,
            foregroundColor: AppColors.backgroundPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
      ),
    );
  }

  /// セクションヘッダー
  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.accentPrimary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.accentPrimary,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  /// 設定カードの構築
  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // アイコン
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accentPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AppColors.accentPrimary,
              size: 20,
            ),
          ),

          const SizedBox(width: 12),

          // テキスト
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),

          // 入力ウィジェット
          child,
        ],
      ),
    );
  }

  /// 数値入力フィールド
  Widget _buildNumberInput({
    required TextEditingController controller,
    required String unit,
    required double min,
    required double max,
    double step = 1.0,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 減少ボタン
        _buildStepButton(
          icon: Icons.remove,
          onPressed: () {
            final current = double.tryParse(controller.text) ?? min;
            final newValue = (current - step).clamp(min, max);
            controller.text = newValue.toStringAsFixed(1);
          },
        ),

        const SizedBox(width: 8),

        // 数値入力
        SizedBox(
          width: 60,
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              filled: true,
              fillColor: AppColors.backgroundSecondary,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.accentPrimary),
              ),
            ),
          ),
        ),

        const SizedBox(width: 4),

        // 単位
        Text(
          unit,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),

        const SizedBox(width: 8),

        // 増加ボタン
        _buildStepButton(
          icon: Icons.add,
          onPressed: () {
            final current = double.tryParse(controller.text) ?? min;
            final newValue = (current + step).clamp(min, max);
            controller.text = newValue.toStringAsFixed(1);
          },
        ),
      ],
    );
  }

  /// ステップボタン（+/-）
  Widget _buildStepButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(
          icon,
          size: 16,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  /// スイッチ
  Widget _buildSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.accentPrimary,
      activeTrackColor: AppColors.accentPrimary.withValues(alpha: 0.3),
      inactiveThumbColor: AppColors.textHint,
      inactiveTrackColor: AppColors.backgroundSecondary,
    );
  }

  /// 閾値プレビュー
  Widget _buildThresholdPreview() {
    final safeThreshold =
        double.tryParse(_safeThresholdController.text) ?? 10.0;
    final dangerThreshold =
        double.tryParse(_dangerThresholdController.text) ?? 50.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.preview,
                size: 16,
                color: AppColors.accentPrimary,
              ),
              SizedBox(width: 8),
              Text(
                'THRESHOLD PREVIEW',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accentPrimary,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // プレビューバー
          Container(
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                colors: [
                  AppColors.statusSafe,
                  AppColors.statusSafe,
                  AppColors.statusWarning,
                  AppColors.statusWarning,
                  AppColors.statusDanger,
                ],
                stops: [
                  0,
                  safeThreshold / 100,
                  safeThreshold / 100,
                  dangerThreshold / 100,
                  dangerThreshold / 100,
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ラベル
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '0',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: AppColors.textHint,
                ),
              ),
              Text(
                '${safeThreshold.toStringAsFixed(0)}μT',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: AppColors.statusSafe,
                ),
              ),
              Text(
                '${dangerThreshold.toStringAsFixed(0)}μT',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: AppColors.statusDanger,
                ),
              ),
              const Text(
                '100+',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ステータス説明
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatusLabel('SAFE', AppColors.statusSafe),
              _buildStatusLabel('WARNING', AppColors.statusWarning),
              _buildStatusLabel('DANGER', AppColors.statusDanger),
            ],
          ),
        ],
      ),
    );
  }

  /// ステータスラベル
  Widget _buildStatusLabel(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            color: color,
          ),
        ),
      ],
    );
  }

  /// リセットボタン
  Widget _buildResetButton() {
    return OutlinedButton.icon(
      onPressed: _resetToDefaults,
      icon: const Icon(Icons.restore, size: 18),
      label: const Text('RESET TO DEFAULTS'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }

  /// 設定を保存
  Future<void> _saveSettings() async {
    // バリデーション
    final referenceMag = double.tryParse(_referenceMagController.text);
    final safeThreshold = double.tryParse(_safeThresholdController.text);
    final dangerThreshold = double.tryParse(_dangerThresholdController.text);
    final interval = double.tryParse(_intervalController.text);

    if (referenceMag == null ||
        safeThreshold == null ||
        dangerThreshold == null ||
        interval == null) {
      _showError('無効な値が入力されています');
      return;
    }

    if (safeThreshold >= dangerThreshold) {
      _showError('安全閾値は危険閾値より小さくしてください');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _settingsService.setReferenceMag(referenceMag);
      await _settingsService.setSafeThreshold(safeThreshold);
      await _settingsService.setDangerThreshold(dangerThreshold);
      await _settingsService.setMeasurementInterval(interval);
      await _settingsService.setAutoMeasurement(_isAutoMeasurement);

      setState(() {
        _isSaving = false;
        _hasChanges = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('設定を保存しました'),
            backgroundColor: AppColors.statusSafe,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showError('設定の保存に失敗しました: $e');
    }
  }

  /// デフォルト値にリセット
  Future<void> _resetToDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        title: const Text(
          'CONFIRM RESET',
          style: TextStyle(
            fontFamily: 'monospace',
            color: AppColors.accentPrimary,
          ),
        ),
        content: const Text(
          '全ての設定をデフォルト値に戻しますか？',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusWarning,
            ),
            child: const Text('RESET'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _settingsService.resetToDefaults();

      setState(() {
        _referenceMagController.text =
            AppConstants.defaultReferenceMag.toStringAsFixed(1);
        _safeThresholdController.text =
            AppConstants.defaultSafeThreshold.toStringAsFixed(1);
        _dangerThresholdController.text =
            AppConstants.defaultDangerThreshold.toStringAsFixed(1);
        _intervalController.text =
            AppConstants.defaultMeasurementInterval.toStringAsFixed(1);
        _isAutoMeasurement = false;
        _hasChanges = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('設定をリセットしました'),
          ),
        );
      }
    }
  }

  /// 戻る処理
  void _onBack() {
    if (_hasChanges) {
      showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.backgroundCard,
          title: const Text(
            'UNSAVED CHANGES',
            style: TextStyle(
              fontFamily: 'monospace',
              color: AppColors.statusWarning,
            ),
          ),
          content: const Text(
            '保存されていない変更があります。破棄しますか？',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusDanger,
              ),
              child: const Text('DISCARD'),
            ),
          ],
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
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


