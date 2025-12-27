/// MAG PLOTTER 描画図形リポジトリ
///
/// 描画図形データのCRUD操作を提供
/// ポリゴン、ポリライン、サークルの永続化を管理
library;

import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/drawing_shape.dart';

/// 描画図形リポジトリ
///
/// 描画図形のデータアクセスを管理
class DrawingShapeRepository {
  /// データベースヘルパー
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// テーブル名
  static const String _tableName = 'drawing_shapes';

  /// 指定ミッションの描画図形をすべて取得
  ///
  /// [missionId] ミッションID
  /// [orderBy] ソート順（デフォルト: 作成日時昇順）
  Future<List<DrawingShape>> getByMissionId(
    int missionId, {
    String orderBy = 'created_at ASC',
  }) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      _tableName,
      where: 'mission_id = ?',
      whereArgs: [missionId],
      orderBy: orderBy,
    );
    return maps.map((map) => DrawingShape.fromMap(map)).toList();
  }

  /// 指定ミッションの表示中の図形のみ取得
  ///
  /// [missionId] ミッションID
  Future<List<DrawingShape>> getVisibleByMissionId(int missionId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      _tableName,
      where: 'mission_id = ? AND is_visible = 1',
      whereArgs: [missionId],
      orderBy: 'created_at ASC',
    );
    return maps.map((map) => DrawingShape.fromMap(map)).toList();
  }

  /// 指定IDの描画図形を取得
  ///
  /// [id] 図形ID
  Future<DrawingShape?> getById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return DrawingShape.fromMap(maps.first);
  }

  /// 描画図形を挿入
  ///
  /// [shape] 挿入する描画図形
  /// 戻り値: 挿入された図形のID
  Future<int> insert(DrawingShape shape) async {
    final db = await _dbHelper.database;
    return await db.insert(
      _tableName,
      shape.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 複数の描画図形を一括挿入
  ///
  /// [shapes] 挿入する描画図形のリスト
  Future<void> insertBatch(List<DrawingShape> shapes) async {
    final db = await _dbHelper.database;
    final batch = db.batch();

    for (final shape in shapes) {
      batch.insert(
        _tableName,
        shape.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// 描画図形を更新
  ///
  /// [shape] 更新する描画図形（IDが必要）
  /// 戻り値: 更新された行数
  Future<int> update(DrawingShape shape) async {
    if (shape.id == null) {
      throw ArgumentError('図形IDが必要です');
    }

    final db = await _dbHelper.database;
    return await db.update(
      _tableName,
      shape.toMap(),
      where: 'id = ?',
      whereArgs: [shape.id],
    );
  }

  /// 描画図形の表示/非表示を切り替え
  ///
  /// [id] 図形ID
  /// [isVisible] 表示するかどうか
  Future<int> setVisibility(int id, bool isVisible) async {
    final db = await _dbHelper.database;
    return await db.update(
      _tableName,
      {
        'is_visible': isVisible ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 描画図形の名前を変更
  ///
  /// [id] 図形ID
  /// [name] 新しい名前
  Future<int> rename(int id, String name) async {
    final db = await _dbHelper.database;
    return await db.update(
      _tableName,
      {
        'name': name,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 描画図形を削除
  ///
  /// [id] 削除する図形のID
  /// 戻り値: 削除された行数
  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 指定ミッションの描画図形をすべて削除
  ///
  /// [missionId] ミッションID
  /// 戻り値: 削除された行数
  Future<int> deleteByMissionId(int missionId) async {
    final db = await _dbHelper.database;
    return await db.delete(
      _tableName,
      where: 'mission_id = ?',
      whereArgs: [missionId],
    );
  }

  /// 指定ミッションの描画図形数を取得
  ///
  /// [missionId] ミッションID
  Future<int> countByMissionId(int missionId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName WHERE mission_id = ?',
      [missionId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 指定ミッションの図形タイプ別統計を取得
  ///
  /// [missionId] ミッションID
  /// 戻り値: 各タイプの図形数
  Future<Map<ShapeType, int>> getTypeCountsByMissionId(int missionId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT type, COUNT(*) as count 
      FROM $_tableName 
      WHERE mission_id = ?
      GROUP BY type
    ''', [missionId]);

    final counts = <ShapeType, int>{};
    for (final row in result) {
      final typeName = row['type'] as String;
      final count = row['count'] as int;
      final type = ShapeType.values.firstWhere(
        (t) => t.name == typeName,
        orElse: () => ShapeType.polygon,
      );
      counts[type] = count;
    }
    return counts;
  }
}


