/// MAG PLOTTER 計測画面
///
/// 磁場計測を行うメイン画面
/// 地図上にヒートマップを表示し、リアルタイムで磁場値を計測
library;

import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../services/magnetometer_service.dart';
import '../../services/location_service.dart';

/// 計測画面
///
/// 主な機能:
/// - OpenStreetMap地図表示
/// - 現在地表示
/// - 磁場計測値のリアルタイム表示
/// - ヒートマップ表示
class MeasurementScreen extends StatefulWidget {
  /// ミッションID（オプション）
  final int? missionId;

  /// ミッション名
  final String missionName;

  const MeasurementScreen({
    super.key,
    this.missionId,
    this.missionName = 'NEW MISSION',
  });

  @override
  State<MeasurementScreen> createState() => _MeasurementScreenState();
}

class _MeasurementScreenState extends State<MeasurementScreen> {
  /// 地図コントローラー
  final MapController _mapController = MapController();

  /// 磁気センサーサービス
  final MagnetometerService _magnetometerService = MagnetometerService();

  /// 位置情報サービス
  final LocationService _locationService = LocationService();

  /// 磁気センサーのサブスクリプション
  StreamSubscription<MagnetometerData>? _magSubscription;

  /// 位置情報のサブスクリプション
  StreamSubscription<LocationData>? _locationSubscription;

  /// 現在位置
  LatLng _currentPosition = const LatLng(
    AppConstants.defaultLatitude,
    AppConstants.defaultLongitude,
  );

  /// 現在の磁場値 [μT]
  double _magField = 46.0;

  /// 現在のノイズ値 [μT]
  double _noise = 0.0;

  /// 現在のステータス
  MagStatus _status = MagStatus.unknown;

  /// 計測ポイントリスト
  final List<_MeasurementPoint> _measurementPoints = [];

  /// 計測中かどうか
  bool _isMeasuring = false;

  /// センサー初期化済みか
  bool _sensorsInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  /// サービスの初期化
  Future<void> _initializeServices() async {
    // 位置情報サービスの初期化
    final locationAvailable = await _locationService.initialize();
    if (locationAvailable) {
      // 現在位置を取得
      final location = await _locationService.getCurrentLocation();
      if (location != null && mounted) {
        setState(() {
          _currentPosition = location.latLng;
        });
        _mapController.move(_currentPosition, AppConstants.defaultZoom);
      }

      // 位置追跡を開始
      await _locationService.startTracking();
      _locationSubscription = _locationService.locationStream.listen((data) {
        if (mounted) {
          setState(() {
            _currentPosition = data.latLng;
          });
        }
      });
    }

    // 磁気センサーの初期化
    final magAvailable = await _magnetometerService.initialize();
    if (magAvailable) {
      _magnetometerService.startListening();
      _magSubscription = _magnetometerService.dataStream.listen((data) {
        if (mounted) {
          setState(() {
            _magField = data.magnitude;
            _noise = data.noise;
            _status = data.status;
          });

          // 計測中なら自動でポイントを追加
          if (_isMeasuring) {
            _addMeasurementPoint(_currentPosition, data.magnitude, data.noise);
          }
        }
      });
    }

    if (mounted) {
      setState(() {
        _sensorsInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _magSubscription?.cancel();
    _locationSubscription?.cancel();
    _magnetometerService.dispose();
    _locationService.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 地図
          _buildMap(),

          // HUDオーバーレイ
          _buildHudOverlay(),

          // 上部パネル（ミッション名・ステータス）
          _buildTopPanel(),

          // 下部パネル（磁場値表示）
          _buildBottomPanel(),

          // 計測ボタン
          _buildMeasureButton(),
        ],
      ),
    );
  }

  /// 地図の構築
  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentPosition,
        initialZoom: AppConstants.defaultZoom,
        minZoom: AppConstants.minZoom,
        maxZoom: AppConstants.maxZoom,
        backgroundColor: AppColors.backgroundPrimary,
        onTap: _onMapTap,
      ),
      children: [
        // タイルレイヤー（OpenStreetMap）
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.visionoid.magplotter',
          tileBuilder: _darkTileBuilder,
        ),

        // 計測ポイントレイヤー
        MarkerLayer(
          markers: _buildMeasurementMarkers(),
        ),

        // 現在位置マーカー
        MarkerLayer(
          markers: [
            Marker(
              point: _currentPosition,
              width: 40,
              height: 40,
              child: _buildCurrentLocationMarker(),
            ),
          ],
        ),
      ],
    );
  }

  /// ダークモード用タイルビルダー
  Widget _darkTileBuilder(BuildContext context, Widget tileWidget, TileImage tile) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0.3, 0, 0, 0, 0,
        0, 0.3, 0, 0, 0,
        0, 0, 0.4, 0, 0,
        0, 0, 0, 1, 0,
      ]),
      child: tileWidget,
    );
  }

  /// 計測ポイントマーカーの構築
  List<Marker> _buildMeasurementMarkers() {
    return _measurementPoints.map((point) {
      return Marker(
        point: point.position,
        width: AppConstants.pointRadius * 2,
        height: AppConstants.pointRadius * 2,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getStatusColor(point.noise),
            border: Border.all(
              color: Colors.white,
              width: AppConstants.pointBorderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: _getStatusColor(point.noise).withValues(alpha: 0.5),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  /// 現在位置マーカーの構築
  Widget _buildCurrentLocationMarker() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.accentPrimary.withValues(alpha: 0.3),
        border: Border.all(
          color: AppColors.accentPrimary,
          width: 3,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.my_location,
          color: AppColors.accentPrimary,
          size: 20,
        ),
      ),
    );
  }

  /// HUDオーバーレイの構築
  Widget _buildHudOverlay() {
    return IgnorePointer(
      child: CustomPaint(
        painter: _HudOverlayPainter(),
        size: Size.infinite,
      ),
    );
  }

  /// 上部パネルの構築
  Widget _buildTopPanel() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.backgroundPrimary,
              AppColors.backgroundPrimary.withValues(alpha: 0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 戻るボタン
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.arrow_back,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(width: 8),

                // ミッション名
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.missionName,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentPrimary,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        'POINTS: ${_measurementPoints.length}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // ステータスインジケーター
                _buildStatusIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ステータスインジケーターの構築
  Widget _buildStatusIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _isMeasuring
            ? AppColors.statusSafe.withValues(alpha: 0.2)
            : AppColors.textHint.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isMeasuring ? AppColors.statusSafe : AppColors.textHint,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isMeasuring ? AppColors.statusSafe : AppColors.textHint,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _isMeasuring ? 'MEASURING' : 'STANDBY',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _isMeasuring ? AppColors.statusSafe : AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  /// 下部パネルの構築
  Widget _buildBottomPanel() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              AppColors.backgroundPrimary,
              AppColors.backgroundPrimary.withValues(alpha: 0.9),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 磁場値パネル
                _buildDataPanel(),

                const SizedBox(height: 80), // 計測ボタン用のスペース
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// データパネルの構築
  Widget _buildDataPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // MAG FIELD
          Expanded(
            child: _buildDataItem(
              label: 'MAG FIELD',
              value: _magField.toStringAsFixed(1),
              unit: 'μT',
              color: AppColors.accentPrimary,
            ),
          ),

          // 区切り線
          Container(
            width: 1,
            height: 60,
            color: AppColors.border,
          ),

          // NOISE
          Expanded(
            child: _buildDataItem(
              label: 'NOISE',
              value: _noise.toStringAsFixed(1),
              unit: 'μT',
              color: _getStatusColor(_noise),
            ),
          ),
        ],
      ),
    );
  }

  /// データアイテムの構築
  Widget _buildDataItem({
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            color: AppColors.textSecondary,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: color.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 計測ボタンの構築
  Widget _buildMeasureButton() {
    return Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: _toggleMeasurement,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isMeasuring ? AppColors.statusDanger : AppColors.accentPrimary,
              boxShadow: [
                BoxShadow(
                  color: (_isMeasuring ? AppColors.statusDanger : AppColors.accentPrimary)
                      .withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              _isMeasuring ? Icons.stop : Icons.play_arrow,
              color: _isMeasuring ? Colors.white : AppColors.backgroundPrimary,
              size: 40,
            ),
          ),
        ),
      ),
    );
  }

  /// ノイズ値に基づいてステータス色を取得
  Color _getStatusColor(double noise) {
    if (noise < AppConstants.defaultSafeThreshold) {
      return AppColors.statusSafe;
    } else if (noise < AppConstants.defaultDangerThreshold) {
      return AppColors.statusWarning;
    } else {
      return AppColors.statusDanger;
    }
  }

  /// 地図タップ時の処理
  void _onMapTap(TapPosition tapPosition, LatLng point) {
    // 手動計測モードで使用
    if (_isMeasuring) {
      _addMeasurementPoint(point, _magField, _noise);
    }
  }

  /// 計測ポイントを追加
  void _addMeasurementPoint(LatLng position, double magField, double noise) {
    setState(() {
      _measurementPoints.add(_MeasurementPoint(
        position: position,
        magField: magField,
        noise: noise,
        timestamp: DateTime.now(),
      ));
    });
  }

  /// 計測の開始/停止を切り替え
  void _toggleMeasurement() {
    setState(() {
      _isMeasuring = !_isMeasuring;
    });

    if (_isMeasuring) {
      // TODO: 計測開始処理
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('計測を開始しました'),
          backgroundColor: AppColors.statusSafe,
        ),
      );
    } else {
      // TODO: 計測停止処理
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('計測を停止しました'),
          backgroundColor: AppColors.textSecondary,
        ),
      );
    }
  }
}

/// 計測ポイントデータ
class _MeasurementPoint {
  /// 位置
  final LatLng position;

  /// 磁場値 [μT]
  final double magField;

  /// ノイズ値 [μT]
  final double noise;

  /// タイムスタンプ
  final DateTime timestamp;

  _MeasurementPoint({
    required this.position,
    required this.magField,
    required this.noise,
    required this.timestamp,
  });
}

/// HUDオーバーレイペインター
class _HudOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accentPrimary.withValues(alpha: 0.1)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // コーナーマーク（左上）
    _drawCornerMark(canvas, paint, 20, 20, true, true);

    // コーナーマーク（右上）
    _drawCornerMark(canvas, paint, size.width - 20, 20, false, true);

    // コーナーマーク（左下）
    _drawCornerMark(canvas, paint, 20, size.height - 20, true, false);

    // コーナーマーク（右下）
    _drawCornerMark(canvas, paint, size.width - 20, size.height - 20, false, false);
  }

  void _drawCornerMark(Canvas canvas, Paint paint, double x, double y, bool left, bool top) {
    const length = 30.0;
    final path = ui.Path();

    if (left) {
      path.moveTo(x, y + (top ? length : -length));
      path.lineTo(x, y);
      path.lineTo(x + length, y);
    } else {
      path.moveTo(x, y + (top ? length : -length));
      path.lineTo(x, y);
      path.lineTo(x - length, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

