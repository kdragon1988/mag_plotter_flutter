/// MAG PLOTTER シェイプ名入力ダイアログ
///
/// 図形を保存する際に名前を入力するダイアログ
library;

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// シェイプ名入力ダイアログ
class ShapeNameDialog extends StatefulWidget {
  /// 初期値
  final String? initialName;

  /// タイトル
  final String title;

  const ShapeNameDialog({
    super.key,
    this.initialName,
    this.title = '図形の名前',
  });

  /// ダイアログを表示
  static Future<String?> show(
    BuildContext context, {
    String? initialName,
    String title = '図形の名前',
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => ShapeNameDialog(
        initialName: initialName,
        title: title,
      ),
    );
  }

  @override
  State<ShapeNameDialog> createState() => _ShapeNameDialogState();
}

class _ShapeNameDialogState extends State<ShapeNameDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.backgroundCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      title: Row(
        children: [
          const Icon(
            Icons.label_outline,
            color: AppColors.accentPrimary,
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            widget.title,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.accentPrimary,
            ),
          ),
        ],
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: const InputDecoration(
          hintText: '名前を入力...',
        ),
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            Navigator.pop(context, value.trim());
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _controller.text.trim();
            if (name.isNotEmpty) {
              Navigator.pop(context, name);
            }
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

