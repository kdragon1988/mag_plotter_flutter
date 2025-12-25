/// MAG PLOTTER ミッションリポジトリ
///
/// ミッションデータのCRUD操作を提供
library;

import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/mission.dart';

/// ミッションリポジトリ
///
/// ミッションのデータアクセスを管理
class MissionRepository {
  /// データベースヘルパー
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// テーブル名
  static const String _tableName = 'missions';

  /// すべてのミッションを取得
  ///
  /// [orderBy] ソート順（デフォルト: 更新日時降順）
  Future<List<Mission>> getAll({String orderBy = 'updated_at DESC'}) async {
    final db = await _dbHelper.database;
    final maps = await db.query(_tableName, orderBy: orderBy);
    return maps.map((map) => Mission.fromMap(map)).toList();
  }

  /// 指定IDのミッションを取得
  ///
  /// [id] ミッションID
  Future<Mission?> getById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Mission.fromMap(maps.first);
  }

  /// ミッションを挿入
  ///
  /// [mission] 挿入するミッション
  /// 戻り値: 挿入されたミッションのID
  Future<int> insert(Mission mission) async {
    final db = await _dbHelper.database;
    return await db.insert(
      _tableName,
      mission.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// ミッションを更新
  ///
  /// [mission] 更新するミッション（IDが必要）
  /// 戻り値: 更新された行数
  Future<int> update(Mission mission) async {
    if (mission.id == null) {
      throw ArgumentError('ミッションIDが必要です');
    }

    final db = await _dbHelper.database;
    final updatedMission = mission.copyWith(updatedAt: DateTime.now());

    return await db.update(
      _tableName,
      updatedMission.toMap(),
      where: 'id = ?',
      whereArgs: [mission.id],
    );
  }

  /// ミッションを削除
  ///
  /// [id] 削除するミッションのID
  /// 戻り値: 削除された行数
  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// ミッション名で検索
  ///
  /// [query] 検索クエリ
  Future<List<Mission>> search(String query) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      _tableName,
      where: 'name LIKE ? OR location LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'updated_at DESC',
    );
    return maps.map((map) => Mission.fromMap(map)).toList();
  }

  /// 完了/未完了でフィルタリング
  ///
  /// [isCompleted] 完了状態でフィルタ
  Future<List<Mission>> getByCompletionStatus(bool isCompleted) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      _tableName,
      where: 'is_completed = ?',
      whereArgs: [isCompleted ? 1 : 0],
      orderBy: 'updated_at DESC',
    );
    return maps.map((map) => Mission.fromMap(map)).toList();
  }

  /// ミッション数を取得
  Future<int> count() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}

