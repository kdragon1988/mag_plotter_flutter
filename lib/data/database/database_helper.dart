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
  static const int _databaseVersion = 3;

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

    // 計測レイヤーテーブル
    await db.execute('''
      CREATE TABLE measurement_layers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mission_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        color_hex TEXT DEFAULT 'FF00FFFF',
        point_size REAL DEFAULT 0.5,
        blur_intensity REAL DEFAULT 0.0,
        is_visible INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (mission_id) REFERENCES missions(id) ON DELETE CASCADE
      )
    ''');

    // 計測ポイントテーブル
    await db.execute('''
      CREATE TABLE measurement_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mission_id INTEGER NOT NULL,
        layer_id INTEGER,
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
        FOREIGN KEY (mission_id) REFERENCES missions(id) ON DELETE CASCADE,
        FOREIGN KEY (layer_id) REFERENCES measurement_layers(id) ON DELETE SET NULL
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
        show_edge_labels INTEGER DEFAULT 1,
        show_name_label INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (mission_id) REFERENCES missions(id) ON DELETE CASCADE
      )
    ''');

    // インデックス作成
    await db.execute(
        'CREATE INDEX idx_measurement_layers_mission ON measurement_layers(mission_id)');
    await db.execute(
        'CREATE INDEX idx_measurement_points_mission ON measurement_points(mission_id)');
    await db.execute(
        'CREATE INDEX idx_measurement_points_layer ON measurement_points(layer_id)');
    await db.execute(
        'CREATE INDEX idx_drawing_shapes_mission ON drawing_shapes(mission_id)');
  }

  /// データベースアップグレード時の処理
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // バージョン2: 描画図形に表示設定カラムを追加
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE drawing_shapes ADD COLUMN show_edge_labels INTEGER DEFAULT 1'
      );
      await db.execute(
        'ALTER TABLE drawing_shapes ADD COLUMN show_name_label INTEGER DEFAULT 1'
      );
    }

    // バージョン3: 計測レイヤー機能を追加
    if (oldVersion < 3) {
      // 計測レイヤーテーブルを作成
      await db.execute('''
        CREATE TABLE IF NOT EXISTS measurement_layers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          mission_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          color_hex TEXT DEFAULT 'FF00FFFF',
          point_size REAL DEFAULT 0.5,
          blur_intensity REAL DEFAULT 0.0,
          is_visible INTEGER DEFAULT 1,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (mission_id) REFERENCES missions(id) ON DELETE CASCADE
        )
      ''');

      // 計測ポイントにlayer_idカラムを追加
      await db.execute(
        'ALTER TABLE measurement_points ADD COLUMN layer_id INTEGER'
      );

      // インデックスを作成
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_measurement_layers_mission ON measurement_layers(mission_id)'
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_measurement_points_layer ON measurement_points(layer_id)'
      );
    }
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

