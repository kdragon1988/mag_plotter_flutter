/// MAG PLOTTER 描画モード
///
/// 地図上での描画モードを定義
library;

/// 描画モード列挙型
enum DrawingMode {
  /// 描画なし（通常の地図操作）
  none,

  /// ポリゴン（多角形）描画
  polygon,

  /// ポリライン（線）描画
  polyline,

  /// サークル（円）描画
  circle,
}

/// DrawingMode拡張
extension DrawingModeExtension on DrawingMode {
  /// 表示名
  String get displayName {
    switch (this) {
      case DrawingMode.none:
        return 'OFF';
      case DrawingMode.polygon:
        return 'ポリゴン';
      case DrawingMode.polyline:
        return 'ライン';
      case DrawingMode.circle:
        return 'サークル';
    }
  }

  /// 短い名前
  String get shortName {
    switch (this) {
      case DrawingMode.none:
        return 'OFF';
      case DrawingMode.polygon:
        return 'POLY';
      case DrawingMode.polyline:
        return 'LINE';
      case DrawingMode.circle:
        return 'CIRCLE';
    }
  }

  /// アイコン
  String get iconName {
    switch (this) {
      case DrawingMode.none:
        return 'touch_app';
      case DrawingMode.polygon:
        return 'hexagon';
      case DrawingMode.polyline:
        return 'timeline';
      case DrawingMode.circle:
        return 'circle';
    }
  }

  /// 描画中かどうか
  bool get isDrawing => this != DrawingMode.none;
}

