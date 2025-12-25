/// MAG PLOTTER ミッション編集ダイアログ
///
/// ミッションの作成・編集を行うダイアログ
/// スパイテック風のフォームデザイン
library;

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/mission.dart';

/// ミッション編集ダイアログ
///
/// 新規作成または既存ミッションの編集を行う
class MissionEditDialog extends StatefulWidget {
  /// 編集対象のミッション（新規作成時はnull）
  final Mission? mission;

  const MissionEditDialog({
    super.key,
    this.mission,
  });

  /// ダイアログを表示
  ///
  /// 戻り値: 保存されたMission、キャンセル時はnull
  static Future<Mission?> show(BuildContext context, {Mission? mission}) {
    return showDialog<Mission>(
      context: context,
      barrierDismissible: false,
      builder: (context) => MissionEditDialog(mission: mission),
    );
  }

  @override
  State<MissionEditDialog> createState() => _MissionEditDialogState();
}

class _MissionEditDialogState extends State<MissionEditDialog> {
  /// フォームキー
  final _formKey = GlobalKey<FormState>();

  /// コントローラー
  late TextEditingController _nameController;
  late TextEditingController _locationController;
  late TextEditingController _assigneeController;
  late TextEditingController _refMagController;
  late TextEditingController _safeThresholdController;
  late TextEditingController _dangerThresholdController;
  late TextEditingController _intervalController;
  late TextEditingController _memoController;

  /// 新規作成モードかどうか
  bool get isNew => widget.mission == null;

  @override
  void initState() {
    super.initState();

    final m = widget.mission;
    _nameController = TextEditingController(text: m?.name ?? '');
    _locationController = TextEditingController(text: m?.location ?? '');
    _assigneeController = TextEditingController(text: m?.assignee ?? '');
    _refMagController = TextEditingController(
      text: (m?.referenceMag ?? AppConstants.defaultReferenceMag).toString(),
    );
    _safeThresholdController = TextEditingController(
      text: (m?.safeThreshold ?? AppConstants.defaultSafeThreshold).toString(),
    );
    _dangerThresholdController = TextEditingController(
      text:
          (m?.dangerThreshold ?? AppConstants.defaultDangerThreshold).toString(),
    );
    _intervalController = TextEditingController(
      text: (m?.measurementInterval ?? AppConstants.defaultMeasurementInterval)
          .toString(),
    );
    _memoController = TextEditingController(text: m?.memo ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _assigneeController.dispose();
    _refMagController.dispose();
    _safeThresholdController.dispose();
    _dangerThresholdController.dispose();
    _intervalController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.backgroundCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ヘッダー
            _buildHeader(),

            // フォーム
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 基本情報セクション
                      _buildSectionTitle('BASIC INFO'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _nameController,
                        label: 'ミッション名 *',
                        icon: Icons.flag,
                        validator: (v) =>
                            v?.isEmpty ?? true ? 'ミッション名を入力してください' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _locationController,
                        label: '場所',
                        icon: Icons.location_on,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _assigneeController,
                        label: '担当者',
                        icon: Icons.person,
                      ),

                      const SizedBox(height: 24),

                      // 閾値設定セクション
                      _buildSectionTitle('THRESHOLD SETTINGS'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildNumberField(
                              controller: _refMagController,
                              label: '基準磁場',
                              unit: 'μT',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildNumberField(
                              controller: _intervalController,
                              label: '計測間隔',
                              unit: '秒',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildNumberField(
                              controller: _safeThresholdController,
                              label: '安全閾値',
                              unit: 'μT',
                              color: AppColors.statusSafe,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildNumberField(
                              controller: _dangerThresholdController,
                              label: '危険閾値',
                              unit: 'μT',
                              color: AppColors.statusDanger,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // メモセクション
                      _buildSectionTitle('MEMO'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _memoController,
                        label: 'メモ',
                        icon: Icons.note,
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ),

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
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isNew ? Icons.add_circle : Icons.edit,
            color: AppColors.accentPrimary,
          ),
          const SizedBox(width: 12),
          Text(
            isNew ? 'NEW MISSION' : 'EDIT MISSION',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.accentPrimary,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  /// セクションタイトルの構築
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: AppColors.accentPrimary.withValues(alpha: 0.7),
        letterSpacing: 2,
      ),
    );
  }

  /// テキストフィールドの構築
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
      ),
    );
  }

  /// 数値フィールドの構築
  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String unit,
    Color? color,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(
        color: color ?? AppColors.textPrimary,
        fontFamily: 'monospace',
        fontWeight: FontWeight.bold,
      ),
      decoration: InputDecoration(
        labelText: label,
        suffixText: unit,
        suffixStyle: TextStyle(
          color: (color ?? AppColors.textPrimary).withValues(alpha: 0.7),
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  /// フッターの構築
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _save,
              child: Text(isNew ? 'CREATE' : 'SAVE'),
            ),
          ),
        ],
      ),
    );
  }

  /// 保存処理
  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final mission = Mission(
      id: widget.mission?.id,
      name: _nameController.text.trim(),
      location: _locationController.text.trim(),
      assignee: _assigneeController.text.trim(),
      referenceMag:
          double.tryParse(_refMagController.text) ?? AppConstants.defaultReferenceMag,
      safeThreshold: double.tryParse(_safeThresholdController.text) ??
          AppConstants.defaultSafeThreshold,
      dangerThreshold: double.tryParse(_dangerThresholdController.text) ??
          AppConstants.defaultDangerThreshold,
      measurementInterval: double.tryParse(_intervalController.text) ??
          AppConstants.defaultMeasurementInterval,
      memo: _memoController.text.trim().isEmpty ? null : _memoController.text.trim(),
      createdAt: widget.mission?.createdAt,
      isCompleted: widget.mission?.isCompleted ?? false,
    );

    Navigator.pop(context, mission);
  }
}

