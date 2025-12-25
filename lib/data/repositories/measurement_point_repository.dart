/// MAG PLOTTER 計測ポイントリポジトリ
///
/// 計測ポイントデータのCRUD操作を提供
library;

import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/measurement_point.dart';

/// 計測ポイントリポジトリ
///
/// 計測ポイントのデータアクセスを管理
class MeasurementPointRepository {
  /// データベースヘルパー
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// テーブル名
  static const String _tableName = 'measurement_points';

  /// 指定ミッションの計測ポイントをすべて取得
  ///
  /// [missionId] ミッションID
  /// [orderBy] ソート順（デフォルト: タイムスタンプ昇順）
  Future<List<MeasurementPoint>> getByMissionId(
    int missionId, {
    String orderBy = 'timestamp ASC',
  }) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      _tableName,
      where: 'mission_id = ?',
      whereArgs: [missionId],
      orderBy: orderBy,
    );
    return maps.map((map) => MeasurementPoint.fromMap(map)).toList();
  }

  /// 指定IDの計測ポイントを取得
  ///
  /// [id] ポイントID
  Future<MeasurementPoint?> getById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return MeasurementPoint.fromMap(maps.first);
  }

  /// 計測ポイントを挿入
  ///
  /// [point] 挿入する計測ポイント
  /// 戻り値: 挿入されたポイントのID
  Future<int> insert(MeasurementPoint point) async {
    final db = await _dbHelper.database;
    return await db.insert(
      _tableName,
      point.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 複数の計測ポイントを一括挿入
  ///
  /// [points] 挿入する計測ポイントのリスト
  Future<void> insertBatch(List<MeasurementPoint> points) async {
    final db = await _dbHelper.database;
    final batch = db.batch();

    for (final point in points) {
      batch.insert(
        _tableName,
        point.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// 計測ポイントを更新
  ///
  /// [point] 更新する計測ポイント（IDが必要）
  /// 戻り値: 更新された行数
  Future<int> update(MeasurementPoint point) async {
    if (point.id == null) {
      throw ArgumentError('ポイントIDが必要です');
    }

    final db = await _dbHelper.database;
    return await db.update(
      _tableName,
      point.toMap(),
      where: 'id = ?',
      whereArgs: [point.id],
    );
  }

  /// 計測ポイントを削除
  ///
  /// [id] 削除するポイントのID
  /// 戻り値: 削除された行数
  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 指定ミッションの計測ポイントをすべて削除
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

  /// 指定ミッションの計測ポイント数を取得
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

  /// 指定ミッションの統計情報を取得
  ///
  /// [missionId] ミッションID
  /// 戻り値: 平均磁場、最大ノイズ、最小ノイズなど
  Future<Map<String, double>> getStatsByMissionId(int missionId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT 
        AVG(mag_field) as avg_mag_field,
        AVG(noise) as avg_noise,
        MAX(noise) as max_noise,
        MIN(noise) as min_noise,
        COUNT(*) as point_count
      FROM $_tableName 
      WHERE mission_id = ?
    ''', [missionId]);

    if (result.isEmpty) {
      return {
        'avg_mag_field': 0,
        'avg_noise': 0,
        'max_noise': 0,
        'min_noise': 0,
        'point_count': 0,
      };
    }

    final row = result.first;
    return {
      'avg_mag_field': (row['avg_mag_field'] as num?)?.toDouble() ?? 0,
      'avg_noise': (row['avg_noise'] as num?)?.toDouble() ?? 0,
      'max_noise': (row['max_noise'] as num?)?.toDouble() ?? 0,
      'min_noise': (row['min_noise'] as num?)?.toDouble() ?? 0,
      'point_count': (row['point_count'] as num?)?.toDouble() ?? 0,
    };
  }
}

