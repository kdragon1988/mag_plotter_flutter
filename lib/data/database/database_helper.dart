/// MAG PLOTTER データベースヘルパー
///
/// SQLiteデータベースの初期化と管理を行う
/// sqfliteパッケージを使用
library;

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// データベースヘルパー
///
/// シングルトンパターンでデータベース接続を管理
class DatabaseHelper {
  /// シングルトンインスタンス
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  /// ファクトリーコンストラクタ
  factory DatabaseHelper() => _instance;

  /// プライベートコンストラクタ
  DatabaseHelper._internal();

  /// データベースインスタンス
  static Database? _database;

  /// データベース名
  static const String _databaseName = 'mag_plotter.db';

  /// データベースバージョン
  static const int _databaseVersion = 1;

  /// データベースを取得
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// データベースを初期化
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// データベース作成時の処理
  Future<void> _onCreate(Database db, int version) async {
    // ミッションテーブル
    await db.execute('''
      CREATE TABLE missions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        location TEXT,
        assignee TEXT,
        reference_mag REAL DEFAULT 46.0,
        safe_threshold REAL DEFAULT 10.0,
        danger_threshold REAL DEFAULT 50.0,
        measurement_interval REAL DEFAULT 1.0,
        memo TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_completed INTEGER DEFAULT 0
      )
    ''');

    // 計測ポイントテーブル
    await db.execute('''
      CREATE TABLE measurement_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mission_id INTEGER NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        altitude REAL,
        accuracy REAL,
        mag_x REAL DEFAULT 0,
        mag_y REAL DEFAULT 0,
        mag_z REAL DEFAULT 0,
        mag_field REAL NOT NULL,
        noise REAL NOT NULL,
        timestamp TEXT NOT NULL,
        memo TEXT,
        FOREIGN KEY (mission_id) REFERENCES missions(id) ON DELETE CASCADE
      )
    ''');

    // 描画図形テーブル
    await db.execute('''
      CREATE TABLE drawing_shapes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mission_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        name TEXT NOT NULL,
        color_hex TEXT DEFAULT 'FFFF9800',
        coordinates_json TEXT NOT NULL,
        radius REAL,
        is_visible INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (mission_id) REFERENCES missions(id) ON DELETE CASCADE
      )
    ''');

    // インデックス作成
    await db.execute(
        'CREATE INDEX idx_measurement_points_mission ON measurement_points(mission_id)');
    await db.execute(
        'CREATE INDEX idx_drawing_shapes_mission ON drawing_shapes(mission_id)');
  }

  /// データベースアップグレード時の処理
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 将来のバージョンアップ時に使用
    // 例: if (oldVersion < 2) { ... }
  }

  /// データベースを閉じる
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  /// データベースを削除（デバッグ用）
  Future<void> deleteDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }
}

