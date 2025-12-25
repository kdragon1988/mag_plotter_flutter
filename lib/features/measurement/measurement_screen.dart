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
import '../../data/models/mission.dart';
import '../../data/models/measurement_point.dart';
import '../../data/models/drawing_shape.dart';
import '../../data/repositories/mission_repository.dart';
import '../../data/repositories/measurement_point_repository.dart';
import '../../services/magnetometer_service.dart';
import '../../services/location_service.dart';
import '../../services/settings_service.dart';
import '../drawing/drawing_mode.dart';
import '../drawing/drawing_controller.dart';
import '../drawing/drawing_toolbar.dart';
import '../drawing/drawing_layer.dart';
import '../drawing/shape_name_dialog.dart';
import 'widgets/measurement_marker.dart';

/// 計測画面
class MeasurementScreen extends StatefulWidget {
  final int? missionId;
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
  // コントローラー
  final MapController _mapController = MapController();
  final MagnetometerService _magnetometerService = MagnetometerService();
  final LocationService _locationService = LocationService();
  final DrawingController _drawingController = DrawingController();

  // サービス
  final SettingsService _settingsService = SettingsService();

  // リポジトリ
  final MissionRepository _missionRepo = MissionRepository();
  final MeasurementPointRepository _pointRepo = MeasurementPointRepository();

  // サブスクリプション
  StreamSubscription<MagnetometerData>? _magSubscription;
  StreamSubscription<LocationData>? _locationSubscription;

  // 自動計測用タイマー
  Timer? _autoMeasurementTimer;

  // 状態
  Mission? _mission;
  LatLng _currentPosition = const LatLng(
    AppConstants.defaultLatitude,
    AppConstants.defaultLongitude,
  );
  double _magField = 46.0;
  double _noise = 0.0;
  MagStatus _status = MagStatus.unknown;
  List<MeasurementPoint> _measurementPoints = [];
  List<DrawingShape> _drawingShapes = [];
  bool _isMeasuring = false;
  bool _isAutoMode = false;
  bool _sensorsInitialized = false;
  bool _showDrawingToolbar = false;
  MeasurementPoint? _selectedPoint;

  @override
  void initState() {
    super.initState();
    _isAutoMode = _settingsService.isAutoMeasurement;
    _loadMission();
    _initializeServices();
  }

  Future<void> _loadMission() async {
    if (widget.missionId != null) {
      final mission = await _missionRepo.getById(widget.missionId!);
      final points = await _pointRepo.getByMissionId(widget.missionId!);
      // TODO: 描画図形の読み込み

      if (mounted) {
        setState(() {
          _mission = mission;
          _measurementPoints = points;
        });

        // 閾値を設定（ミッション設定があればそれを使用、なければグローバル設定）
        _magnetometerService.setThresholds(
          referenceMag: mission?.referenceMag ?? _settingsService.referenceMag,
          safeThreshold:
              mission?.safeThreshold ?? _settingsService.safeThreshold,
          dangerThreshold:
              mission?.dangerThreshold ?? _settingsService.dangerThreshold,
        );
      }
    } else {
      // ミッションがない場合はグローバル設定を使用
      _magnetometerService.setThresholds(
        referenceMag: _settingsService.referenceMag,
        safeThreshold: _settingsService.safeThreshold,
        dangerThreshold: _settingsService.dangerThreshold,
      );
    }
  }

  Future<void> _initializeServices() async {
    // 位置情報
    final locationAvailable = await _locationService.initialize();
    if (locationAvailable) {
      final location = await _locationService.getCurrentLocation();
      if (location != null && mounted) {
        setState(() => _currentPosition = location.latLng);
        _mapController.move(_currentPosition, AppConstants.defaultZoom);
      }

      await _locationService.startTracking();
      _locationSubscription = _locationService.locationStream.listen((data) {
        if (mounted) setState(() => _currentPosition = data.latLng);
      });
    }

    // 磁気センサー
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
        }
      });
    }

    if (mounted) setState(() => _sensorsInitialized = true);
  }

  @override
  void dispose() {
    _autoMeasurementTimer?.cancel();
    _magSubscription?.cancel();
    _locationSubscription?.cancel();
    _magnetometerService.dispose();
    _locationService.dispose();
    _drawingController.dispose();
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

          // 上部パネル
          _buildTopPanel(),

          // 下部パネル
          _buildBottomPanel(),

          // 描画ツールバー
          if (_showDrawingToolbar)
            Positioned(
              top: 120,
              left: 0,
              right: 0,
              child: DrawingToolbar(
                controller: _drawingController,
                onSave: _saveDrawing,
                onClose: () => setState(() {
                  _showDrawingToolbar = false;
                  _drawingController.setMode(DrawingMode.none);
                }),
              ),
            ),

          // 計測ボタン
          if (!_showDrawingToolbar) _buildMeasureButton(),

          // 選択ポイント情報
          if (_selectedPoint != null) _buildSelectedPointInfo(),
        ],
      ),
    );
  }

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
        // タイルレイヤー
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.visionoid.magplotter',
          tileBuilder: _darkTileBuilder,
        ),

        // 保存済み図形レイヤー
        SavedShapesLayer(
          shapes: _drawingShapes,
          onShapeTap: _onShapeTap,
        ),

        // 描画中レイヤー
        DrawingOverlay(controller: _drawingController),

        // 計測ポイントレイヤー
        MarkerLayer(
          markers: _measurementPoints.map((point) {
            return Marker(
              point: LatLng(point.latitude, point.longitude),
              width: 24,
              height: 24,
              child: MeasurementMarker(
                noise: point.noise,
                safeThreshold: _mission?.safeThreshold ?? AppConstants.defaultSafeThreshold,
                dangerThreshold: _mission?.dangerThreshold ?? AppConstants.defaultDangerThreshold,
                isSelected: _selectedPoint?.id == point.id,
                onTap: () => _selectPoint(point),
              ),
            );
          }).toList(),
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

  Widget _buildCurrentLocationMarker() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.accentPrimary.withValues(alpha: 0.3),
        border: Border.all(color: AppColors.accentPrimary, width: 3),
      ),
      child: const Center(
        child: Icon(Icons.my_location, color: AppColors.accentPrimary, size: 20),
      ),
    );
  }

  Widget _buildHudOverlay() {
    return IgnorePointer(
      child: CustomPaint(
        painter: _HudOverlayPainter(),
        size: Size.infinite,
      ),
    );
  }

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
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.missionName.toUpperCase(),
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
                _buildStatusIndicator(),
                const SizedBox(width: 8),
                // 自動/手動モード切り替えボタン
                IconButton(
                  onPressed: _toggleAutoMode,
                  tooltip: _isAutoMode ? '手動計測に切り替え' : '自動計測に切り替え',
                  icon: Icon(
                    _isAutoMode ? Icons.autorenew : Icons.touch_app,
                    color: _isAutoMode
                        ? AppColors.accentPrimary
                        : AppColors.textSecondary,
                  ),
                ),
                // 描画ボタン
                IconButton(
                  onPressed: () => setState(() => _showDrawingToolbar = !_showDrawingToolbar),
                  icon: Icon(
                    Icons.draw,
                    color: _showDrawingToolbar ? AppColors.accentPrimary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    final statusColor = _status == MagStatus.safe
        ? AppColors.statusSafe
        : _status == MagStatus.warning
            ? AppColors.statusWarning
            : _status == MagStatus.danger
                ? AppColors.statusDanger
                : AppColors.textHint;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _isMeasuring ? 'MEASURING' : 'STANDBY',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

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
                _buildDataPanel(),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDataPanel() {
    final statusColor = _noise < (_mission?.safeThreshold ?? AppConstants.defaultSafeThreshold)
        ? AppColors.statusSafe
        : _noise < (_mission?.dangerThreshold ?? AppConstants.defaultDangerThreshold)
            ? AppColors.statusWarning
            : AppColors.statusDanger;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildDataItem(
              label: 'MAG FIELD',
              value: _magField.toStringAsFixed(1),
              unit: 'μT',
              color: AppColors.accentPrimary,
            ),
          ),
          Container(width: 1, height: 60, color: AppColors.border),
          Expanded(
            child: _buildDataItem(
              label: 'NOISE',
              value: _noise.toStringAsFixed(1),
              unit: 'μT',
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildMeasureButton() {
    return Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // モード表示
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.backgroundCard.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isAutoMode ? Icons.autorenew : Icons.touch_app,
                    size: 14,
                    color: _isAutoMode
                        ? AppColors.accentPrimary
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isAutoMode ? 'AUTO' : 'MANUAL',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _isAutoMode
                          ? AppColors.accentPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 計測ボタン
            GestureDetector(
              onTap: _toggleMeasurement,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isMeasuring
                      ? AppColors.statusDanger
                      : AppColors.accentPrimary,
                  boxShadow: [
                    BoxShadow(
                      color: (_isMeasuring
                              ? AppColors.statusDanger
                              : AppColors.accentPrimary)
                          .withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  _isMeasuring ? Icons.stop : Icons.play_arrow,
                  color:
                      _isMeasuring ? Colors.white : AppColors.backgroundPrimary,
                  size: 40,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedPointInfo() {
    if (_selectedPoint == null) return const SizedBox.shrink();

    return Positioned(
      bottom: 200,
      left: 16,
      right: 16,
      child: MeasurementInfoPopup(
        magField: _selectedPoint!.magField,
        noise: _selectedPoint!.noise,
        timestamp: _selectedPoint!.timestamp,
        onClose: () => setState(() => _selectedPoint = null),
      ),
    );
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    // 描画モードの場合
    if (_drawingController.isDrawing) {
      _drawingController.addPoint(point);
      return;
    }

    // 選択解除
    if (_selectedPoint != null) {
      setState(() => _selectedPoint = null);
      return;
    }

    // 計測中の場合は手動ポイント追加
    if (_isMeasuring) {
      _addMeasurementPoint(point);
    }
  }

  void _selectPoint(MeasurementPoint point) {
    setState(() => _selectedPoint = point);
  }

  void _onShapeTap(DrawingShape shape) {
    // TODO: 図形の詳細表示/編集
  }

  Future<void> _addMeasurementPoint(LatLng position) async {
    if (widget.missionId == null) return;

    final point = MeasurementPoint(
      missionId: widget.missionId!,
      latitude: position.latitude,
      longitude: position.longitude,
      magField: _magField,
      noise: _noise,
      magX: _magnetometerService.latestData.x,
      magY: _magnetometerService.latestData.y,
      magZ: _magnetometerService.latestData.z,
    );

    try {
      final id = await _pointRepo.insert(point);
      final savedPoint = MeasurementPoint(
        id: id,
        missionId: point.missionId,
        latitude: point.latitude,
        longitude: point.longitude,
        magField: point.magField,
        noise: point.noise,
        magX: point.magX,
        magY: point.magY,
        magZ: point.magZ,
        timestamp: point.timestamp,
      );

      setState(() => _measurementPoints.add(savedPoint));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ポイントの保存に失敗しました'),
            backgroundColor: AppColors.statusDanger,
          ),
        );
      }
    }
  }

  void _toggleMeasurement() {
    setState(() => _isMeasuring = !_isMeasuring);

    if (_isMeasuring) {
      // 計測開始
      if (_isAutoMode) {
        _startAutoMeasurement();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isAutoMode
              ? '自動計測を開始しました（${_settingsService.measurementInterval}秒間隔）'
              : '計測を開始しました（地図タップでポイント追加）'),
          backgroundColor: AppColors.statusSafe,
        ),
      );
    } else {
      // 計測停止
      _stopAutoMeasurement();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('計測を停止しました'),
          backgroundColor: AppColors.textSecondary,
        ),
      );
    }
  }

  /// 自動計測を開始
  void _startAutoMeasurement() {
    _autoMeasurementTimer?.cancel();
    final intervalMs =
        (_settingsService.measurementInterval * 1000).round();
    _autoMeasurementTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) => _addAutoMeasurementPoint(),
    );
  }

  /// 自動計測を停止
  void _stopAutoMeasurement() {
    _autoMeasurementTimer?.cancel();
    _autoMeasurementTimer = null;
  }

  /// 自動計測でポイントを追加
  Future<void> _addAutoMeasurementPoint() async {
    if (!_isMeasuring || !_isAutoMode) return;
    await _addMeasurementPoint(_currentPosition);
  }

  /// 自動/手動モードを切り替え
  void _toggleAutoMode() {
    setState(() => _isAutoMode = !_isAutoMode);

    if (_isMeasuring) {
      if (_isAutoMode) {
        _startAutoMeasurement();
      } else {
        _stopAutoMeasurement();
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isAutoMode ? '自動計測モードに切り替えました' : '手動計測モードに切り替えました'),
      ),
    );
  }

  Future<void> _saveDrawing() async {
    if (widget.missionId == null) return;

    final name = await ShapeNameDialog.show(context);
    if (name == null || name.isEmpty) return;

    final shape = _drawingController.complete(
      missionId: widget.missionId!,
      name: name,
    );

    if (shape != null) {
      setState(() => _drawingShapes.add(shape));
      // TODO: データベースに保存

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('図形を保存しました'),
            backgroundColor: AppColors.statusSafe,
          ),
        );
      }
    }
  }
}

class _HudOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accentPrimary.withValues(alpha: 0.1)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    _drawCornerMark(canvas, paint, 20, 20, true, true);
    _drawCornerMark(canvas, paint, size.width - 20, 20, false, true);
    _drawCornerMark(canvas, paint, 20, size.height - 20, true, false);
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
