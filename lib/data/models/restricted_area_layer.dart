/// 警戒区域レイヤーモデル
/// 
/// ドローン飛行に関わる警戒区域（DID、航空施設、小型無人機等禁止区域）を
/// 管理するためのデータモデル。
/// 
/// 【主な機能】
/// - レイヤーの表示/非表示切り替え
/// - 塗りつぶし色・境界色・透明度の設定
/// - 法的根拠・参照URL・データ年月の情報保持
library;

import 'package:flutter/material.dart';

/// 警戒区域の種類
enum RestrictedAreaType {
  /// DID（人口集中地区）
  did,
  /// 航空施設周辺
  airport,
  /// 小型無人機等飛行禁止区域
  noFlyZone,
}

/// 警戒区域レイヤー
class RestrictedAreaLayer {
  /// レイヤーの種類
  final RestrictedAreaType type;
  
  /// レイヤー名（日本語）
  final String name;
  
  /// レイヤーの説明
  final String description;
  
  /// 法的根拠
  final String legalBasis;
  
  /// 参照URL
  final String referenceUrl;
  
  /// データの年月
  final String dataDate;
  
  /// GeoJSONファイル名
  final String geoJsonFileName;
  
  /// 表示/非表示
  bool isVisible;
  
  /// 塗りつぶし色（ARGB hex）
  String fillColorHex;
  
  /// 境界線色（ARGB hex）
  String strokeColorHex;
  
  /// 塗りつぶしの透明度（0.0-1.0）
  double fillOpacity;
  
  /// 境界線の太さ
  double strokeWidth;
  
  /// 境界線の表示/非表示
  bool showStroke;

  RestrictedAreaLayer({
    required this.type,
    required this.name,
    required this.description,
    required this.legalBasis,
    required this.referenceUrl,
    required this.dataDate,
    required this.geoJsonFileName,
    this.isVisible = false,
    this.fillColorHex = 'FFFF0000',
    this.strokeColorHex = 'FFFF0000',
    this.fillOpacity = 0.3,
    this.strokeWidth = 1.0,
    this.showStroke = true,
  });

  /// 塗りつぶし色を取得
  Color get fillColor {
    final color = Color(int.parse(fillColorHex, radix: 16));
    return color.withValues(alpha: fillOpacity);
  }

  /// 境界線色を取得
  Color get strokeColor => Color(int.parse(strokeColorHex, radix: 16));

  /// デフォルトのレイヤー設定を取得
  static List<RestrictedAreaLayer> getDefaultLayers() {
    return [
      // DID（人口集中地区）
      RestrictedAreaLayer(
        type: RestrictedAreaType.did,
        name: 'DID（人口集中地区）',
        description: '国勢調査の結果から一定の基準により設定された人口集中地区。'
            '原則として人口密度が4,000人/km²以上の地域。'
            'ドローンの飛行には国土交通大臣の許可が必要。',
        legalBasis: '航空法第132条の85第1項第1号\n'
            '無人航空機を飛行させる空域（人口集中地区の上空）',
        referenceUrl: 'https://www.stat.go.jp/data/chiri/1-1.html',
        dataDate: '2015年（平成27年）国勢調査',
        geoJsonFileName: 'did_japan.geojson',
        isVisible: false,
        fillColorHex: 'FFFF6B6B', // 赤系
        strokeColorHex: 'FFFF0000',
        fillOpacity: 0.25,
        strokeWidth: 1.0,
      ),
      
      // 航空施設周辺
      RestrictedAreaLayer(
        type: RestrictedAreaType.airport,
        name: '航空施設周辺',
        description: '空港やヘリポート等の周辺空域（進入表面、転移表面、水平表面等）。'
            '航空機の離着陸に影響を及ぼす恐れがある区域。'
            'ドローンの飛行には空港管理者・国土交通大臣の許可が必要。\n\n'
            '※現在、地理院地図のタイルサービスは非公開のため、'
            'ローカルデータを使用しています。',
        legalBasis: '航空法第132条の85第1項第2号\n'
            '空港等の周辺の空域',
        referenceUrl: 'https://www.mlit.go.jp/koku/koku_tk2_000023.html',
        dataDate: 'プレースホルダー（正式データ準備中）',
        geoJsonFileName: 'airport_restriction.geojson',
        isVisible: false,
        fillColorHex: 'FF6B8EFF', // 青系
        strokeColorHex: 'FF0000FF',
        fillOpacity: 0.25,
        strokeWidth: 1.0,
      ),
      
      // 小型無人機等飛行禁止区域
      RestrictedAreaLayer(
        type: RestrictedAreaType.noFlyZone,
        name: '小型無人機等禁止区域',
        description: '国の重要施設（国会議事堂、首相官邸、皇居等）、'
            '外国公館、原子力事業所等の周辺地域。'
            '小型無人機等飛行禁止法により飛行が禁止されている区域。',
        legalBasis: '小型無人機等飛行禁止法\n'
            '（重要施設の周辺地域の上空における小型無人機等の飛行の禁止に関する法律）',
        referenceUrl: 'https://www.npa.go.jp/bureau/security/kogatamujinki/index.html',
        dataDate: 'プレースホルダー（正式データ準備中）',
        geoJsonFileName: 'no_fly_zone.geojson',
        isVisible: false,
        fillColorHex: 'FFFFB347', // オレンジ系
        strokeColorHex: 'FFFF8C00',
        fillOpacity: 0.25,
        strokeWidth: 1.0,
      ),
    ];
  }

  /// 設定をコピー
  RestrictedAreaLayer copyWith({
    bool? isVisible,
    String? fillColorHex,
    String? strokeColorHex,
    double? fillOpacity,
    double? strokeWidth,
    bool? showStroke,
  }) {
    return RestrictedAreaLayer(
      type: type,
      name: name,
      description: description,
      legalBasis: legalBasis,
      referenceUrl: referenceUrl,
      dataDate: dataDate,
      geoJsonFileName: geoJsonFileName,
      isVisible: isVisible ?? this.isVisible,
      fillColorHex: fillColorHex ?? this.fillColorHex,
      strokeColorHex: strokeColorHex ?? this.strokeColorHex,
      fillOpacity: fillOpacity ?? this.fillOpacity,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      showStroke: showStroke ?? this.showStroke,
    );
  }

  /// SharedPreferencesに保存するためのMap
  Map<String, dynamic> toMap() {
    return {
      'type': type.index,
      'isVisible': isVisible,
      'fillColorHex': fillColorHex,
      'strokeColorHex': strokeColorHex,
      'fillOpacity': fillOpacity,
      'strokeWidth': strokeWidth,
      'showStroke': showStroke,
    };
  }

  /// SharedPreferencesから復元
  void applySettings(Map<String, dynamic> map) {
    isVisible = map['isVisible'] as bool? ?? isVisible;
    fillColorHex = map['fillColorHex'] as String? ?? fillColorHex;
    strokeColorHex = map['strokeColorHex'] as String? ?? strokeColorHex;
    fillOpacity = (map['fillOpacity'] as num?)?.toDouble() ?? fillOpacity;
    strokeWidth = (map['strokeWidth'] as num?)?.toDouble() ?? strokeWidth;
    showStroke = map['showStroke'] as bool? ?? showStroke;
  }

  @override
  String toString() {
    return 'RestrictedAreaLayer(type: $type, name: $name, isVisible: $isVisible)';
  }
}

