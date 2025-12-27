# VISIONOID MAG PLOTTER (Flutter版)

🧭 ドローンショー用磁場計測アプリ - iOS/Android対応

## 概要

ドローンショーの実施場所における磁場ノイズを計測・可視化するアプリケーションのFlutter版です。
iOS/Android両対応のクロスプラットフォームアプリとして開発。

## 関連リポジトリ

| プラットフォーム | リポジトリ | 状態 |
|-----------------|-----------|------|
| **Android（安定版）** | [android_mag_plotter](https://github.com/kdragon1988/android_mag_plotter) | ✅ v2.1.0 リリース済み |
| **Flutter（iOS/Android）** | このリポジトリ | 🚧 開発中 |

## 機能

### 📍 計測機能
- GPS位置情報のリアルタイム取得
- 磁気センサーによる磁場強度計測（自動モード）
- ノイズレベルの計算・表示
- 計測レイヤー管理（複数レイヤー対応）
- 点群サイズ・ぼかし・色のカスタマイズ

### 🧭 コンパス機能
- リアルタイム方位表示（8方位対応）
- 地図の北方向インジケーター
- タップで北向きにリセット

### ✏️ 作図機能
- ポリゴン（多角形）描画
- ポリライン（線）描画
- サークル（円）描画
- 距離・面積・周囲長の自動計算
- 辺の長さ表示（ON/OFF可能）
- ドラッグ&ドロップでレイヤー順序変更

### 🗺️ マップ機能
- OpenStreetMap標準マップ
- Google Maps衛星写真
- 住所検索（Nominatim API）
- 現在位置へジャンプ

### ⚠️ ドローン飛行警戒区域
- **DID（人口集中地区）**: 2015年国勢調査データ
- **航空施設周辺**: 主要7空港の制限空域
- **小型無人機等禁止区域**: 重要施設周辺
- 各レイヤーの表示ON/OFF
- 色・透明度・境界線のカスタマイズ

### 💾 データ管理
- ミッションごとのデータ保存
- 計測ポイントの管理
- 描画図形の永続化
- SQLiteローカルデータベース

### ⚙️ 設定機能
- 基準磁場値の設定
- 安全/危険閾値の設定
- ダークモード対応

## スクリーンショット

```
┌─────────────────────────────────────┐
│ ← [ミッション名]    ● STANDBY  [🧭] │
│                                     │
│                                     │
│           [MAP VIEW]                │
│                                     │
│                        ┌──────────┐ │
│                        │   検索 🔍│ │
│                        │   現在地📍│ │
│                        │   作図 ✏️│ │
│                        │ 磁場計測📡│ │
│                        │ レイヤー📚│ │
│                        │   点群 🔵│ │
│                        │   地図 🗺️│ │
│                        │     ➡️   │ │
│                        └──────────┘ │
└─────────────────────────────────────┘
```

## 開発環境

- Flutter 3.38.5+
- Dart 3.10.4+
- Xcode 16+ (iOS)
- Android Studio (Android)

## 必要なAPIキー

### Google Maps API
`ios/Runner/Info.plist` および `android/app/src/main/AndroidManifest.xml` に設定:
```xml
<key>GOOGLE_MAPS_API_KEY</key>
<string>YOUR_API_KEY</string>
```

## セットアップ

```bash
# リポジトリをクローン
git clone https://github.com/kdragon1988/mag_plotter_flutter.git
cd mag_plotter_flutter

# 依存関係のインストール
flutter pub get

# iOSの場合
cd ios && pod install && cd ..

# 開発サーバー起動
flutter run
```

## 使用パッケージ

| パッケージ | 用途 |
|-----------|------|
| `flutter_map` | 地図表示 |
| `latlong2` | 座標計算 |
| `geolocator` | GPS位置情報 |
| `sensors_plus` | 磁気センサー |
| `sqflite` | SQLiteデータベース |
| `shared_preferences` | 設定保存 |
| `http` | API通信 |

## ライセンス

Proprietary - VISIONOID
