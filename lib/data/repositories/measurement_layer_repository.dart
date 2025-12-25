/// MAG PLOTTER 計測レイヤーリポジトリ
///
/// 計測レイヤーのCRUD操作を提供
library;

import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/measurement_layer.dart';

/// 計測レイヤーリポジトリ
///
/// SQLiteデータベースとの通信を担当
class MeasurementLayerRepository {
  /// データベースヘルパー
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// テーブル名
  static const String _tableName = 'measurement_layers';

  /// レイヤーを作成
  ///
  /// [layer] 作成するレイヤー
  /// 戻り値: 作成されたレイヤーのID
  Future<int> create(MeasurementLayer layer) async {
    final db = await _dbHelper.database;
    return await db.insert(
      _tableName,
      layer.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// ミッションに紐づくレイヤー一覧を取得
  ///
  /// [missionId] ミッションID
  Future<List<MeasurementLayer>> getByMission(int missionId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      _tableName,
      where: 'mission_id = ?',
      whereArgs: [missionId],
      orderBy: 'created_at ASC',
    );
    return maps.map((map) => MeasurementLayer.fromMap(map)).toList();
  }

  /// レイヤーを更新
  ///
  /// [layer] 更新するレイヤー
  Future<int> update(MeasurementLayer layer) async {
    if (layer.id == null) {
      throw ArgumentError('レイヤーIDがnullです');
    }
    final db = await _dbHelper.database;
    return await db.update(
      _tableName,
      layer.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [layer.id],
    );
  }

  /// レイヤーを削除
  ///
  /// [id] 削除するレイヤーID
  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    // 紐づく計測ポイントも削除（外部キー制約で自動削除されるが明示的に）
    await db.delete(
      'measurement_points',
      where: 'layer_id = ?',
      whereArgs: [id],
    );
    return await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// レイヤーの表示/非表示を切り替え
  ///
  /// [id] レイヤーID
  /// [isVisible] 表示状態
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

  /// レイヤーをリネーム
  ///
  /// [id] レイヤーID
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

  /// 点群設定を更新
  ///
  /// [id] レイヤーID
  /// [pointSize] 点のサイズ
  /// [blurIntensity] ぼかし強度
  Future<int> updatePointSettings(int id, double pointSize, double blurIntensity) async {
    final db = await _dbHelper.database;
    return await db.update(
      _tableName,
      {
        'point_size': pointSize,
        'blur_intensity': blurIntensity,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// ミッションに紐づく全レイヤーを削除
  ///
  /// [missionId] ミッションID
  Future<int> deleteByMission(int missionId) async {
    final db = await _dbHelper.database;
    return await db.delete(
      _tableName,
      where: 'mission_id = ?',
      whereArgs: [missionId],
    );
  }
}

