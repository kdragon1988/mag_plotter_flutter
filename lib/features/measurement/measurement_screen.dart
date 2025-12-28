/// MAG PLOTTER 計測画面
///
/// 磁場計測を行うメイン画面
/// 地図上にヒートマップを表示し、リアルタイムで磁場値を計測
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/mission.dart';
import '../../data/models/measurement_point.dart';
import '../../data/models/measurement_layer.dart';
import '../../data/models/drawing_shape.dart';
import '../../data/repositories/mission_repository.dart';
import '../../data/repositories/measurement_point_repository.dart';
import '../../data/repositories/measurement_layer_repository.dart';
import '../../data/repositories/drawing_shape_repository.dart';
import '../../services/magnetometer_service.dart';
import '../../services/location_service.dart';
import '../../services/settings_service.dart';
import '../../services/geojson_service.dart';
import '../../services/airport_tile_service.dart';
import '../../data/models/restricted_area_layer.dart';
import '../drawing/drawing_mode.dart';
import '../drawing/drawing_controller.dart';
import '../drawing/drawing_toolbar.dart';
import '../drawing/drawing_layer.dart';
import '../drawing/shape_name_dialog.dart';
import 'widgets/measurement_marker.dart';
import 'widgets/compass_widget.dart';

// ColorExtension用
export '../../data/models/drawing_shape.dart' show ColorExtension;

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
  final GeoJsonService _geoJsonService = GeoJsonService();
  final AirportTileService _airportTileService = AirportTileService();

  // リポジトリ
  final MissionRepository _missionRepo = MissionRepository();
  final MeasurementPointRepository _pointRepo = MeasurementPointRepository();
  final MeasurementLayerRepository _layerRepo = MeasurementLayerRepository();
  final DrawingShapeRepository _shapeRepo = DrawingShapeRepository();

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
  double _heading = 0.0;
  double _mapRotation = 0.0;
  MagStatus _status = MagStatus.unknown;
  bool _isHeadingUpMode = false; // true: 自分の向きに追従, false: 北固定
  List<MeasurementPoint> _measurementPoints = [];
  List<DrawingShape> _drawingShapes = [];
  List<MeasurementLayer> _measurementLayers = [];
  MeasurementLayer? _selectedMeasurementLayer;
  bool _isMeasuring = false;
  bool _sensorsInitialized = false;
  bool _showDrawingToolbar = false;
  bool _isSatelliteMode = false;
  bool _showEdgeLabels = true;
  bool _showLayerPanel = false;
  bool _showMeasurementLayerPanel = false;
  bool _showRestrictedAreaPanel = false;
  bool _showMagPanel = false;
  bool _isToolbarExpanded = true;
  MeasurementPoint? _selectedPoint;
  
  // 警戒区域レイヤー
  List<RestrictedAreaLayer> _restrictedAreaLayers = [];
  Map<RestrictedAreaType, List<List<LatLng>>> _restrictedAreaPolygons = {};
  Timer? _viewportUpdateTimer;

  @override
  void initState() {
    super.initState();
    _loadMission();
    _initializeServices();
    _initializeRestrictedAreaLayers();
  }

  /// 警戒区域レイヤーを初期化
  Future<void> _initializeRestrictedAreaLayers() async {
    _restrictedAreaLayers = RestrictedAreaLayer.getDefaultLayers();
    // 保存された設定を復元（将来的にSharedPreferencesから読み込む）
    if (mounted) {
      setState(() {});
    }
  }

  /// 警戒区域のポリゴンデータを読み込む
  Future<void> _loadRestrictedAreaPolygons(RestrictedAreaLayer layer) async {
    // GeoJSONファイルがある場合は読み込む
    if (layer.geoJsonFileName.isNotEmpty) {
      if (!_geoJsonService.isLoaded(layer.geoJsonFileName)) {
        debugPrint('警戒区域: ${layer.name} のGeoJSONを読み込み中...');
        await _geoJsonService.loadGeoJson(layer.geoJsonFileName);
        debugPrint('警戒区域: ${layer.name} 読み込み完了 (${_geoJsonService.getFeatureCount(layer.geoJsonFileName)} features)');
      }
    }
    
    // ビューポートに基づいてポリゴンを更新
    _updateRestrictedAreaForViewport();
  }

  // 空港エリアタイルサービスは現在非公開のため無効化
  // 将来的に地理院地図のkokuareaレイヤーが公開されたら有効化
  // Future<void> _loadAirportAreaForViewport() async { ... }

  /// 現在のビューポートに基づいて警戒区域ポリゴンを更新
  void _updateRestrictedAreaForViewport() {
    // 表示中のレイヤーがなければスキップ
    final hasVisibleLayers = _restrictedAreaLayers.any((l) => l.isVisible);
    if (!hasVisibleLayers) return;

    final bounds = _mapController.camera.visibleBounds;
    final viewport = BoundingBox(
      minLat: bounds.south,
      maxLat: bounds.north,
      minLng: bounds.west,
      maxLng: bounds.east,
    );

    bool hasChanges = false;
    for (final layer in _restrictedAreaLayers) {
      if (!layer.isVisible) continue;
      
      // GeoJSONファイルがある場合は読み込む
      if (layer.geoJsonFileName.isNotEmpty) {
        final visiblePolygons = _geoJsonService.getVisiblePolygons(
          layer.geoJsonFileName,
          viewport,
        );
        
        // 変更があった場合のみ更新
        if (_restrictedAreaPolygons[layer.type]?.length != visiblePolygons.length) {
          _restrictedAreaPolygons[layer.type] = visiblePolygons;
          hasChanges = true;
        }
      }
    }
    
    if (hasChanges && mounted) {
      setState(() {});
    }
  }

  /// マップ位置変更時のコールバック（デバウンス処理）
  void _onMapPositionChanged(MapCamera camera, bool hasGesture) {
    // マップの回転を追跡（コンパス表示用）
    if (_mapRotation != camera.rotation) {
      setState(() {
        _mapRotation = camera.rotation;
      });
    }

    // 警戒区域レイヤーが表示中の場合のみ更新
    final hasVisibleLayers = _restrictedAreaLayers.any((l) => l.isVisible);
    if (!hasVisibleLayers) return;

    // デバウンス: 300ms間隔で更新（パフォーマンス最適化）
    _viewportUpdateTimer?.cancel();
    _viewportUpdateTimer = Timer(const Duration(milliseconds: 300), () {
      _updateRestrictedAreaForViewport();
    });
  }

  Future<void> _loadMission() async {
    if (widget.missionId != null) {
      final mission = await _missionRepo.getById(widget.missionId!);
      final points = await _pointRepo.getByMissionId(widget.missionId!);
      final shapes = await _shapeRepo.getByMissionId(widget.missionId!);
      final layers = await _layerRepo.getByMission(widget.missionId!);

      if (mounted) {
        setState(() {
          _mission = mission;
          _measurementPoints = points;
          _drawingShapes = shapes;
          _measurementLayers = layers;
          // 最初のレイヤーを選択（あれば）
          if (layers.isNotEmpty && _selectedMeasurementLayer == null) {
            _selectedMeasurementLayer = layers.first;
          }
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
            _heading = data.heading;
            _status = data.status;
          });
          
          // ヘディングアップモード時は地図を回転
          if (_isHeadingUpMode && _mapController.camera.rotation != -data.heading) {
            _mapController.rotate(-data.heading);
          }
        }
      });
    }

    if (mounted) setState(() => _sensorsInitialized = true);
  }

  @override
  void dispose() {
    _autoMeasurementTimer?.cancel();
    _viewportUpdateTimer?.cancel();
    _magSubscription?.cancel();
    _locationSubscription?.cancel();
    _magnetometerService.dispose();
    _locationService.dispose();
    _drawingController.dispose();
    _mapController.dispose();
    _airportTileService.dispose();
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

          // 描画ツールバー
          if (_showDrawingToolbar)
            Positioned(
              top: 70,
              left: 8,
              right: 8,
              child: DrawingToolbar(
                controller: _drawingController,
                onSave: _saveDrawing,
                onClose: () => setState(() {
                  _showDrawingToolbar = false;
                  _drawingController.setMode(DrawingMode.none);
                }),
              ),
            ),

          // コンパス表示（右上）
          _buildCompassDisplay(),

          // 右側ボタン群
          _buildSideButtons(),

          // MAG計測パネル
          if (_showMagPanel) _buildMagPanel(),

          // レイヤー管理パネル（描画図形）
          if (_showLayerPanel) _buildLayerPanel(),

          // 計測レイヤーパネル
          if (_showMeasurementLayerPanel) _buildMeasurementLayerPanel(),

          // 選択ポイント情報
          if (_selectedPoint != null) _buildSelectedPointInfo(),
        ],
      ),
    );
  }

  /// コンパス表示
  Widget _buildCompassDisplay() {
    return Positioned(
      top: 0,
      right: 12,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            // コンパスウィジェット
            GestureDetector(
              onTap: () {
                // タップでモード切り替え
                setState(() {
                  _isHeadingUpMode = !_isHeadingUpMode;
                });
                if (_isHeadingUpMode) {
                  // ヘディングアップモード開始
                  _mapController.rotate(-_heading);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('ヘディングアップモード（進行方向が上）'),
                      duration: Duration(seconds: 1),
                      backgroundColor: AppColors.accentPrimary,
                    ),
                  );
                } else {
                  // 北固定モード
                  _mapController.rotate(0);
                  setState(() {
                    _mapRotation = 0;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('ノースアップモード（北が上）'),
                      duration: Duration(seconds: 1),
                      backgroundColor: AppColors.textSecondary,
                    ),
                  );
                }
              },
              onLongPress: () {
                // 長押しで北リセット（ヘディングアップモードも解除）
                setState(() {
                  _isHeadingUpMode = false;
                  _mapRotation = 0;
                });
                _mapController.rotate(0);
              },
              child: Stack(
                children: [
                  CompassWidget(
                    heading: _heading,
                    mapRotation: _mapRotation,
                    size: 52,
                  ),
                  // ヘディングアップモードインジケーター
                  if (_isHeadingUpMode)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.accentPrimary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.navigation,
                          size: 8,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // 方位テキスト表示（モード表示付き）
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _isHeadingUpMode
                    ? AppColors.accentPrimary.withValues(alpha: 0.9)
                    : AppColors.backgroundCard.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isHeadingUpMode ? AppColors.accentPrimary : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isHeadingUpMode) ...[
                    const Icon(
                      Icons.navigation,
                      size: 10,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    '${_heading.toStringAsFixed(0)}° ${_getDirectionName(_heading)}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _isHeadingUpMode ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 方位の方角名を取得（8方位）
  String _getDirectionName(double heading) {
    if (heading >= 337.5 || heading < 22.5) return 'N';
    if (heading >= 22.5 && heading < 67.5) return 'NE';
    if (heading >= 67.5 && heading < 112.5) return 'E';
    if (heading >= 112.5 && heading < 157.5) return 'SE';
    if (heading >= 157.5 && heading < 202.5) return 'S';
    if (heading >= 202.5 && heading < 247.5) return 'SW';
    if (heading >= 247.5 && heading < 292.5) return 'W';
    if (heading >= 292.5 && heading < 337.5) return 'NW';
    return 'N';
  }

  /// 右側ボタン群
  Widget _buildSideButtons() {
    return Positioned(
      right: 12,
      bottom: 100,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 展開時のボタン群
          if (_isToolbarExpanded) ...[
            // 検索ボタン
            _buildLabeledSideButton(
              icon: Icons.search,
              label: '検索',
              isActive: false,
              onTap: _showSearchDialog,
            ),
            const SizedBox(height: 6),
            // 現在位置に移動ボタン
            _buildLabeledSideButton(
              icon: Icons.my_location,
              label: '現在地',
              isActive: false,
              onTap: _moveToCurrentLocation,
            ),
            const SizedBox(height: 6),
            // 作図ボタン
            _buildLabeledSideButton(
              icon: Icons.draw,
              label: '作図',
              isActive: _showDrawingToolbar,
              onTap: () => setState(() => _showDrawingToolbar = !_showDrawingToolbar),
            ),
            const SizedBox(height: 6),
            // MAG計測パネルボタン
            _buildLabeledSideButton(
              icon: Icons.sensors,
              label: '磁場計測',
              isActive: _showMagPanel || _isMeasuring,
              badgeColor: _isMeasuring ? AppColors.statusDanger : null,
              onTap: () => setState(() {
                _showMagPanel = !_showMagPanel;
                if (_showMagPanel) {
                  _showLayerPanel = false;
                  _showMeasurementLayerPanel = false;
                }
              }),
            ),
            const SizedBox(height: 6),
            // 描画レイヤー管理ボタン
            _buildLabeledSideButton(
              icon: Icons.layers,
              label: 'レイヤー',
              isActive: _showLayerPanel,
              onTap: () => setState(() {
                _showLayerPanel = !_showLayerPanel;
                if (_showLayerPanel) {
                  _showMeasurementLayerPanel = false;
                  _showMagPanel = false;
                }
              }),
            ),
            const SizedBox(height: 6),
            // 計測レイヤー管理ボタン
            _buildLabeledSideButton(
              icon: Icons.scatter_plot,
              label: '点群',
              isActive: _showMeasurementLayerPanel,
              onTap: () => setState(() {
                _showMeasurementLayerPanel = !_showMeasurementLayerPanel;
                if (_showMeasurementLayerPanel) {
                  _showLayerPanel = false;
                  _showMagPanel = false;
                }
              }),
            ),
            const SizedBox(height: 6),
            // マップタイプ切替
            _buildLabeledSideButton(
              icon: _isSatelliteMode ? Icons.satellite_alt : Icons.map_outlined,
              label: _isSatelliteMode ? '衛星' : '地図',
              isActive: _isSatelliteMode,
              onTap: () => setState(() => _isSatelliteMode = !_isSatelliteMode),
            ),
            const SizedBox(height: 6),
          ],
          // 展開/折りたたみボタン
          _buildSideButton(
            icon: _isToolbarExpanded ? Icons.chevron_right : Icons.menu,
            isActive: !_isToolbarExpanded,
            badgeColor: _isMeasuring && !_isToolbarExpanded ? AppColors.statusDanger : null,
            onTap: () => setState(() {
              _isToolbarExpanded = !_isToolbarExpanded;
              // 折りたたみ時はパネルを閉じる
              if (!_isToolbarExpanded) {
                _showMagPanel = false;
                _showLayerPanel = false;
                _showMeasurementLayerPanel = false;
              }
            }),
          ),
        ],
      ),
    );
  }

  /// ラベル付きサイドボタンを構築
  Widget _buildLabeledSideButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    Color? badgeColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? AppColors.accentPrimary : AppColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isActive ? AppColors.accentPrimary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isActive ? AppColors.accentPrimary : AppColors.textSecondary,
                ),
                if (badgeColor != null)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: badgeColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.backgroundCard, width: 1),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// サイドボタンを構築
  Widget _buildSideButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    Color? badgeColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.backgroundCard.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isActive ? AppColors.accentPrimary : AppColors.border,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 18,
              color: isActive ? AppColors.accentPrimary : AppColors.textSecondary,
            ),
          ),
          // バッジ表示（計測中インジケーター等）
          if (badgeColor != null)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.backgroundCard, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// MAG計測パネル
  Widget _buildMagPanel() {
    final safeThreshold = _mission?.safeThreshold ?? AppConstants.defaultSafeThreshold;
    final dangerThreshold = _mission?.dangerThreshold ?? AppConstants.defaultDangerThreshold;
    final statusColor = _noise < safeThreshold
        ? AppColors.statusSafe
        : _noise < dangerThreshold
            ? AppColors.statusWarning
            : AppColors.statusDanger;

    return Positioned(
      right: 56,
      bottom: 100,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ヘッダー
            Row(
              children: [
                Icon(
                  Icons.sensors,
                  size: 16,
                  color: _isMeasuring ? AppColors.statusDanger : AppColors.accentPrimary,
                ),
                const SizedBox(width: 6),
                Text(
                  _isMeasuring ? 'MEASURING' : 'MAG SENSOR',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _isMeasuring ? AppColors.statusDanger : AppColors.accentPrimary,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            
            // レベルメーター（オーディオゲージ風）
            _buildMagLevelMeter(
              noise: _noise,
              safeThreshold: safeThreshold,
              dangerThreshold: dangerThreshold,
            ),
            const SizedBox(height: 10),
            
            // データ表示
            Row(
              children: [
                Expanded(
                  child: _buildMagDataItem(
                    label: 'MAG',
                    value: _magField.toStringAsFixed(1),
                    unit: 'μT',
                    color: AppColors.accentPrimary,
                  ),
                ),
                Container(width: 1, height: 36, color: AppColors.border),
                Expanded(
                  child: _buildMagDataItem(
                    label: 'NOISE',
                    value: _noise.toStringAsFixed(1),
                    unit: 'μT',
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            
            // レイヤー選択
            GestureDetector(
              onTap: () => setState(() {
                _showMagPanel = false;
                _showMeasurementLayerPanel = true;
              }),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.backgroundPrimary,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.scatter_plot,
                      size: 12,
                      color: _selectedMeasurementLayer?.color ?? AppColors.textHint,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _selectedMeasurementLayer?.name ?? 'レイヤー未選択',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: _selectedMeasurementLayer != null
                              ? AppColors.textPrimary
                              : AppColors.statusWarning,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: AppColors.textHint,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            
            // 基準値表示とリセットボタン
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.backgroundPrimary,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'REF',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 8,
                            color: AppColors.textHint,
                          ),
                        ),
                        Text(
                          '${_magnetometerService.referenceMag.toStringAsFixed(1)} μT',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _calibrateMagnetometer,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _magnetometerService.isCalibrating
                            ? AppColors.statusWarning
                            : AppColors.accentSecondary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _magnetometerService.isCalibrating ? 'CAL...' : 'RESET',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            // 計測ボタン
            GestureDetector(
              onTap: _toggleMeasurement,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _isMeasuring
                      ? AppColors.statusDanger
                      : AppColors.accentPrimary,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: (_isMeasuring
                              ? AppColors.statusDanger
                              : AppColors.accentPrimary)
                          .withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isMeasuring ? Icons.stop : Icons.play_arrow,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isMeasuring ? 'STOP' : 'START',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// MAGパネル用データ表示
  Widget _buildMagDataItem({
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 8,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              unit,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 8,
                color: color.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// MAGレベルメーター（オーディオゲージ風）
  Widget _buildMagLevelMeter({
    required double noise,
    required double safeThreshold,
    required double dangerThreshold,
  }) {
    // メーターの最大値（danger閾値の2倍）
    final maxValue = dangerThreshold * 2;
    // 現在値の割合（0.0〜1.0）
    final ratio = (noise / maxValue).clamp(0.0, 1.0);
    
    // 16セグメントのレベルメーター
    const segmentCount = 16;
    final activeSegments = (ratio * segmentCount).ceil();
    
    // 閾値の位置を計算
    final safeSegmentEnd = (safeThreshold / maxValue * segmentCount).floor();
    final warningSegmentEnd = (dangerThreshold / maxValue * segmentCount).floor();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          // メーターバー
          Row(
            children: List.generate(segmentCount, (index) {
              final isActive = index < activeSegments;
              Color segmentColor;
              
              if (index < safeSegmentEnd) {
                // 安全域（緑）
                segmentColor = isActive
                    ? AppColors.statusSafe
                    : AppColors.statusSafe.withValues(alpha: 0.15);
              } else if (index < warningSegmentEnd) {
                // 警告域（黄）
                segmentColor = isActive
                    ? AppColors.statusWarning
                    : AppColors.statusWarning.withValues(alpha: 0.15);
              } else {
                // 危険域（赤）
                segmentColor = isActive
                    ? AppColors.statusDanger
                    : AppColors.statusDanger.withValues(alpha: 0.15);
              }
              
              return Expanded(
                child: Container(
                  height: 14,
                  margin: EdgeInsets.only(
                    right: index < segmentCount - 1 ? 2 : 0,
                  ),
                  decoration: BoxDecoration(
                    color: segmentColor,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: segmentColor.withValues(alpha: 0.6),
                              blurRadius: 4,
                              spreadRadius: 0,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          // スケール表示
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 7,
                  color: AppColors.textHint,
                ),
              ),
              Text(
                '${safeThreshold.toInt()}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 7,
                  color: AppColors.statusSafe.withValues(alpha: 0.8),
                ),
              ),
              Text(
                '${dangerThreshold.toInt()}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 7,
                  color: AppColors.statusWarning.withValues(alpha: 0.8),
                ),
              ),
              Text(
                '${maxValue.toInt()}μT',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 7,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// レイヤー管理パネル
  Widget _buildLayerPanel() {
    return Positioned(
      right: 56,
      bottom: 100,
      child: Container(
        width: 260,
        constraints: const BoxConstraints(maxHeight: 400),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ヘッダー
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.border),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.layers, size: 16, color: AppColors.accentPrimary),
                  const SizedBox(width: 8),
                  const Text(
                    'LAYERS',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _showLayerPanel = false),
                    child: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            // スクロール可能なコンテンツ
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 警戒区域セクション
                    _buildRestrictedAreaSection(),
                    
                    // 区切り線
                    const Divider(color: AppColors.border, height: 1),
                    
                    // 描画図形セクション
                    _buildDrawingShapesSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 警戒区域セクション
  Widget _buildRestrictedAreaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // セクションヘッダー
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: AppColors.backgroundSecondary,
          child: const Row(
            children: [
              Icon(Icons.warning_amber, size: 14, color: AppColors.statusWarning),
              SizedBox(width: 6),
              Text(
                '飛行警戒区域',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        // レイヤーリスト
        ...List.generate(_restrictedAreaLayers.length, (index) {
          final layer = _restrictedAreaLayers[index];
          return _buildRestrictedAreaLayerItem(layer, index);
        }),
      ],
    );
  }

  /// 警戒区域レイヤーアイテム
  Widget _buildRestrictedAreaLayerItem(RestrictedAreaLayer layer, int index) {
    return GestureDetector(
      onTap: () => _toggleRestrictedAreaLayer(layer),
      onDoubleTap: () => _showRestrictedAreaDetail(layer),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.border.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: Row(
          children: [
            // 色インジケーター
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: layer.fillColor,
                border: Border.all(color: layer.strokeColor, width: 1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            // レイヤー名
            Expanded(
              child: Text(
                layer.name,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: layer.isVisible 
                      ? AppColors.textPrimary 
                      : AppColors.textHint,
                  decoration: layer.isVisible 
                      ? null 
                      : TextDecoration.lineThrough,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 表示切り替え
            Icon(
              layer.isVisible ? Icons.visibility : Icons.visibility_off,
              size: 16,
              color: layer.isVisible 
                  ? AppColors.accentPrimary 
                  : AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }

  /// 警戒区域レイヤーの表示/非表示を切り替え
  Future<void> _toggleRestrictedAreaLayer(RestrictedAreaLayer layer) async {
    // 表示ONの場合、ポリゴンデータを読み込む
    if (!layer.isVisible) {
      await _loadRestrictedAreaPolygons(layer);
    }
    
    setState(() {
      layer.isVisible = !layer.isVisible;
    });
  }

  /// 警戒区域の詳細を表示
  void _showRestrictedAreaDetail(RestrictedAreaLayer layer) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _RestrictedAreaDetailPanel(
        layer: layer,
        onUpdate: (updatedLayer) {
          setState(() {
            final index = _restrictedAreaLayers.indexWhere(
              (l) => l.type == updatedLayer.type,
            );
            if (index != -1) {
              _restrictedAreaLayers[index] = updatedLayer;
            }
          });
        },
      ),
    );
  }

  /// 描画図形セクション
  Widget _buildDrawingShapesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // セクションヘッダー
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: AppColors.backgroundSecondary,
          child: const Row(
            children: [
              Icon(Icons.draw, size: 14, color: AppColors.accentPrimary),
              SizedBox(width: 6),
              Text(
                '描画図形',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              Spacer(),
              // ドラッグヒント
              Icon(Icons.drag_indicator, size: 12, color: AppColors.textHint),
            ],
          ),
        ),
        // 図形リスト（ドラッグ&ドロップ対応）
        if (_drawingShapes.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              '図形がありません',
              style: TextStyle(
                color: AppColors.textHint,
                fontSize: 11,
              ),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: _drawingShapes.length,
            onReorder: _onReorderShapes,
            proxyDecorator: (child, index, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  final scale = Tween<double>(begin: 1.0, end: 1.05).animate(animation);
                  return Transform.scale(
                    scale: scale.value,
                    child: Material(
                      elevation: 8,
                      color: AppColors.backgroundCard,
                      borderRadius: BorderRadius.circular(4),
                      child: child,
                    ),
                  );
                },
                child: child,
              );
            },
            itemBuilder: (context, index) {
              final shape = _drawingShapes[index];
              return _buildLayerItem(shape, index, key: ValueKey(shape.id));
            },
          ),
      ],
    );
  }

  /// 図形の重ね順を変更
  void _onReorderShapes(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final shape = _drawingShapes.removeAt(oldIndex);
      _drawingShapes.insert(newIndex, shape);
    });
  }

  /// 計測レイヤーパネル
  Widget _buildMeasurementLayerPanel() {
    return Positioned(
      right: 56,
      bottom: 150,
      child: Container(
        width: 260,
        constraints: const BoxConstraints(maxHeight: 350),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ヘッダー
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.border),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.scatter_plot, size: 16, color: AppColors.accentPrimary),
                  const SizedBox(width: 8),
                  const Text(
                    '計測レイヤー',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  // 追加ボタン
                  GestureDetector(
                    onTap: _createMeasurementLayer,
                    child: const Icon(Icons.add, size: 18, color: AppColors.accentPrimary),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _showMeasurementLayerPanel = false),
                    child: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            // 選択中レイヤー表示
            if (_selectedMeasurementLayer != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: const BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    const Text(
                      '保存先: ',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textHint,
                      ),
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _selectedMeasurementLayer!.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _selectedMeasurementLayer!.name,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            // レイヤーリスト
            if (_measurementLayers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '計測レイヤーがありません\n「+」から追加してください',
                  style: TextStyle(
                    color: AppColors.textHint,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _measurementLayers.length,
                  itemBuilder: (context, index) {
                    final layer = _measurementLayers[index];
                    return _buildMeasurementLayerItem(layer);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 計測レイヤーアイテム
  Widget _buildMeasurementLayerItem(MeasurementLayer layer) {
    final isSelected = _selectedMeasurementLayer?.id == layer.id;
    final pointCount = _measurementPoints.where((p) => p.layerId == layer.id).length;

    return GestureDetector(
      onTap: () => setState(() => _selectedMeasurementLayer = layer),
      onDoubleTap: () {
        setState(() => _showMeasurementLayerPanel = false);
        _showMeasurementLayerActions(layer);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentPrimary.withValues(alpha: 0.1) : null,
          border: const Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: Row(
          children: [
            // 選択インジケータ
            if (isSelected)
              const Icon(Icons.check_circle, size: 14, color: AppColors.accentPrimary)
            else
              Icon(Icons.radio_button_unchecked, size: 14, color: layer.color),
            const SizedBox(width: 8),
            // 色インジケータ
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: layer.color.withValues(alpha: layer.isVisible ? 1.0 : 0.3),
                shape: BoxShape.circle,
                border: Border.all(
                  color: layer.isVisible ? Colors.white.withValues(alpha: 0.5) : Colors.transparent,
                  width: 1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 名前とポイント数
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    layer.name,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: layer.isVisible ? AppColors.textPrimary : AppColors.textHint,
                      decoration: layer.isVisible ? null : TextDecoration.lineThrough,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$pointCount ポイント',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
            // 表示/非表示ボタン
            GestureDetector(
              onTap: () => _toggleMeasurementLayerVisibility(layer),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  layer.isVisible ? Icons.visibility : Icons.visibility_off,
                  size: 16,
                  color: layer.isVisible ? AppColors.textSecondary : AppColors.textHint,
                ),
              ),
            ),
            // 削除ボタン
            GestureDetector(
              onTap: () => _deleteMeasurementLayer(layer),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.delete_outline, size: 16, color: AppColors.statusDanger),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 計測レイヤーを作成
  Future<void> _createMeasurementLayer() async {
    if (widget.missionId == null) return;

    final name = await _showLayerNameDialog();
    if (name == null || name.isEmpty) return;

    final layer = MeasurementLayer(
      missionId: widget.missionId!,
      name: name,
      color: AppColors.drawingColors[_measurementLayers.length % AppColors.drawingColors.length],
    );

    try {
      final id = await _layerRepo.create(layer);
      final savedLayer = layer.copyWith(id: id);

      setState(() {
        _measurementLayers.add(savedLayer);
        _selectedMeasurementLayer = savedLayer;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('レイヤーの作成に失敗しました'),
            backgroundColor: AppColors.statusDanger,
          ),
        );
      }
    }
  }

  /// レイヤー名入力ダイアログ
  Future<String?> _showLayerNameDialog({String? initialName}) async {
    final controller = TextEditingController(text: initialName);
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        title: const Text('レイヤー名', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: '例: 磁場計測1',
            hintStyle: TextStyle(color: AppColors.textHint),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// 計測レイヤーの表示/非表示を切り替え
  Future<void> _toggleMeasurementLayerVisibility(MeasurementLayer layer) async {
    if (layer.id == null) return;

    final newVisibility = !layer.isVisible;
    await _layerRepo.setVisibility(layer.id!, newVisibility);

    setState(() {
      final index = _measurementLayers.indexWhere((l) => l.id == layer.id);
      if (index != -1) {
        _measurementLayers[index] = layer.copyWith(isVisible: newVisibility);
      }
    });
  }

  /// 計測レイヤーを削除
  Future<void> _deleteMeasurementLayer(MeasurementLayer layer) async {
    if (layer.id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        title: const Text('レイヤーを削除', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          '「${layer.name}」を削除しますか？\nこのレイヤーの計測ポイントも全て削除されます。',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除', style: TextStyle(color: AppColors.statusDanger)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _layerRepo.delete(layer.id!);

    setState(() {
      _measurementLayers.removeWhere((l) => l.id == layer.id);
      _measurementPoints.removeWhere((p) => p.layerId == layer.id);
      if (_selectedMeasurementLayer?.id == layer.id) {
        _selectedMeasurementLayer = _measurementLayers.isNotEmpty ? _measurementLayers.first : null;
      }
    });
  }

  /// 計測レイヤーの詳細メニューを表示
  void _showMeasurementLayerActions(MeasurementLayer layer) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _MeasurementLayerEditPanel(
        layer: layer,
        onUpdate: (updatedLayer) async {
          await _layerRepo.update(updatedLayer);
          setState(() {
            final index = _measurementLayers.indexWhere((l) => l.id == layer.id);
            if (index != -1) {
              _measurementLayers[index] = updatedLayer;
            }
            if (_selectedMeasurementLayer?.id == layer.id) {
              _selectedMeasurementLayer = updatedLayer;
            }
          });
        },
        onDelete: () => _deleteMeasurementLayer(layer),
      ),
    );
  }

  /// レイヤーアイテム
  Widget _buildLayerItem(DrawingShape shape, int index, {Key? key}) {
    return GestureDetector(
      key: key,
      onDoubleTap: () {
        setState(() => _showLayerPanel = false); // パネルを閉じる
        _showShapeActions(shape); // 編集パネルを表示
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: Row(
          children: [
            // ドラッグハンドル（長押しでドラッグ）
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.drag_indicator,
                  size: 16,
                  color: AppColors.textHint,
                ),
              ),
            ),
            // 色インジケータ
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: shape.color,
                shape: shape.type == ShapeType.circle
                    ? BoxShape.circle
                    : BoxShape.rectangle,
                borderRadius: shape.type != ShapeType.circle
                    ? BorderRadius.circular(2)
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            // 名前
            Expanded(
              child: Text(
                shape.name,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: shape.isVisible ? AppColors.textPrimary : AppColors.textHint,
                  decoration: shape.isVisible ? null : TextDecoration.lineThrough,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // アクションボタン
            _buildLayerActionButton(
              icon: Icons.my_location,
              onTap: () => _moveToShape(shape),
              tooltip: '移動',
            ),
            _buildLayerActionButton(
              icon: Icons.delete_outline,
              onTap: () => _deleteShape(shape),
              tooltip: '削除',
              isDanger: true,
            ),
          ],
        ),
      ),
    );
  }

  /// レイヤーアクションボタン
  Widget _buildLayerActionButton({
    required IconData icon,
    required VoidCallback? onTap,
    required String tooltip,
    bool isDanger = false,
  }) {
    final isEnabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Icon(
          icon,
          size: 16,
          color: !isEnabled
              ? AppColors.textHint.withValues(alpha: 0.3)
              : isDanger
                  ? AppColors.statusDanger
                  : AppColors.textSecondary,
        ),
      ),
    );
  }

  /// 図形の位置へ移動
  void _moveToShape(DrawingShape shape) {
    final center = shape.center;
    if (center != null) {
      _mapController.move(center, _mapController.camera.zoom);
    }
  }


  /// 図形を削除
  Future<void> _deleteShape(DrawingShape shape) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        title: const Text(
          '図形の削除',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          '「${shape.name}」を削除しますか？',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除', style: TextStyle(color: AppColors.statusDanger)),
          ),
        ],
      ),
    );

    if (confirmed == true && shape.id != null) {
      try {
        await _shapeRepo.delete(shape.id!);
        setState(() {
          _drawingShapes.removeWhere((s) => s.id == shape.id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('「${shape.name}」を削除しました'),
              backgroundColor: AppColors.statusSafe,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('削除に失敗しました: $e'),
              backgroundColor: AppColors.statusDanger,
            ),
          );
        }
      }
    }
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
        onPositionChanged: _onMapPositionChanged,
      ),
      children: [
        // タイルレイヤー（標準 or 衛星）
        // 衛星モード: Google Maps 衛星写真タイル
        if (_isSatelliteMode)
          TileLayer(
            urlTemplate:
                'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}',
            userAgentPackageName: 'com.visionoid.magplotter',
          )
        else
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.visionoid.magplotter',
          ),

        // 警戒区域ポリゴンレイヤー
        ..._buildRestrictedAreaLayers(),

        // 保存済み図形レイヤー
        SavedShapesLayer(
          shapes: _drawingShapes,
          onShapeTap: _onShapeTap,
        ),

        // 描画中レイヤー
        DrawingOverlay(
          controller: _drawingController,
          showEdgeLabels: _showEdgeLabels,
        ),

        // 計測ポイントレイヤー（レイヤーごとに表示）
        ..._buildMeasurementPointLayers(),

        // タップ検出用マーカー
        MarkerLayer(
          markers: _measurementPoints.map((point) {
            return Marker(
              point: LatLng(point.latitude, point.longitude),
              width: 30,
              height: 30,
              child: GestureDetector(
                onTap: () => _selectPoint(point),
                child: Container(color: Colors.transparent),
              ),
            );
          }).toList(),
        ),

        // 現在位置マーカー
        MarkerLayer(
          markers: [
            Marker(
              point: _currentPosition,
              width: 24,
              height: 24,
              child: _buildCurrentLocationMarker(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCurrentLocationMarker() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.accentPrimary.withValues(alpha: 0.3),
        border: Border.all(color: AppColors.accentPrimary, width: 2),
      ),
      child: const Center(
        child: Icon(Icons.my_location, color: AppColors.accentPrimary, size: 12),
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
            padding: const EdgeInsets.only(left: 8, right: 80, top: 4, bottom: 4),
            child: Row(
              children: [
                // 戻るボタン
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                // タイトル・ステータス
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.missionName.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentPrimary,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'POINTS: ${_measurementPoints.length}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9,
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

  /// 警戒区域ポリゴンレイヤーを構築
  List<Widget> _buildRestrictedAreaLayers() {
    final layers = <Widget>[];

    for (final layer in _restrictedAreaLayers) {
      if (!layer.isVisible) continue;
      
      final polygons = _restrictedAreaPolygons[layer.type];
      if (polygons == null || polygons.isEmpty) continue;

      // ポリゴンレイヤー
      layers.add(
        PolygonLayer(
          polygons: polygons.map((points) {
            return Polygon(
              points: points,
              color: layer.fillColor,
              borderColor: layer.showStroke ? layer.strokeColor : Colors.transparent,
              borderStrokeWidth: layer.showStroke ? layer.strokeWidth : 0,
              isFilled: true,
            );
          }).toList(),
        ),
      );
    }

    return layers;
  }

  /// 計測ポイントレイヤーを構築（レイヤーごとに分けて表示）
  List<Widget> _buildMeasurementPointLayers() {
    final layers = <Widget>[];

    // レイヤーなしのポイント（後方互換）
    final noLayerPoints = _measurementPoints.where((p) => p.layerId == null).toList();
    if (noLayerPoints.isNotEmpty) {
      layers.add(CircleLayer(
        circles: noLayerPoints.map((point) {
          final color = _getPointColor(point);
          final isSelected = _selectedPoint?.id == point.id;
          return CircleMarker(
            point: LatLng(point.latitude, point.longitude),
            radius: 0.25,
            useRadiusInMeter: true,
            color: color.withValues(alpha: 0.7),
            borderColor: isSelected ? Colors.white : color,
            borderStrokeWidth: isSelected ? 3 : 2,
          );
        }).toList(),
      ));
    }

    // 各計測レイヤーのポイント
    for (final layer in _measurementLayers) {
      if (!layer.isVisible) continue;

      final layerPoints = _measurementPoints.where((p) => p.layerId == layer.id).toList();
      if (layerPoints.isEmpty) continue;

      final pointSize = layer.pointSize;
      final blurIntensity = layer.blurIntensity;

      // ぼかし効果がある場合は、ImageFilterを使用
      if (blurIntensity > 0) {
        layers.add(
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: blurIntensity * 5,
              sigmaY: blurIntensity * 5,
            ),
            child: CircleLayer(
              circles: layerPoints.map((point) {
                final color = _getPointColor(point);
                final isSelected = _selectedPoint?.id == point.id;
                return CircleMarker(
                  point: LatLng(point.latitude, point.longitude),
                  radius: pointSize / 2,
                  useRadiusInMeter: true,
                  color: color.withValues(alpha: 0.7),
                  borderColor: isSelected ? Colors.white : color,
                  borderStrokeWidth: isSelected ? 3 : 2,
                );
              }).toList(),
            ),
          ),
        );
      } else {
        layers.add(CircleLayer(
          circles: layerPoints.map((point) {
            final color = _getPointColor(point);
            final isSelected = _selectedPoint?.id == point.id;
            return CircleMarker(
              point: LatLng(point.latitude, point.longitude),
              radius: pointSize / 2,
              useRadiusInMeter: true,
              color: color.withValues(alpha: 0.7),
              borderColor: isSelected ? Colors.white : color,
              borderStrokeWidth: isSelected ? 3 : 2,
            );
          }).toList(),
        ));
      }
    }

    return layers;
  }

  /// 計測ポイントの色を取得（ノイズ値に基づく）
  Color _getPointColor(MeasurementPoint point) {
    final safe = _mission?.safeThreshold ?? AppConstants.defaultSafeThreshold;
    final danger = _mission?.dangerThreshold ?? AppConstants.defaultDangerThreshold;

    if (point.noise < safe) {
      return AppColors.statusSafe;
    } else if (point.noise < danger) {
      return AppColors.statusWarning;
    } else {
      return AppColors.statusDanger;
    }
  }

  /// 住所検索ダイアログを表示
  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => _SearchDialog(
        onLocationSelected: _moveToLocation,
      ),
    );
  }

  /// 指定位置に移動
  void _moveToLocation(double lat, double lon) {
    final newPosition = LatLng(lat, lon);
    setState(() => _currentPosition = newPosition);
    _mapController.move(newPosition, 17.0);
  }

  /// 現在位置に地図を移動
  void _moveToCurrentLocation() {
    _mapController.move(_currentPosition, 17.0);
  }

  void _onShapeTap(DrawingShape shape) {
    _showShapeActions(shape);
  }

  /// 図形のアクションメニューを表示
  void _showShapeActions(DrawingShape shape) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            // 現在の図形を取得
            final shapeIndex = _drawingShapes.indexWhere((s) => s.id == shape.id);
            final currentShape = shapeIndex >= 0 ? _drawingShapes[shapeIndex] : shape;

            return _ShapeEditPanelContent(
              shape: currentShape,
              onToggleChanged: (field, value) async {
                if (shapeIndex < 0) return;
                
                DrawingShape updated;
                switch (field) {
                  case 'visible':
                    updated = currentShape.copyWith(isVisible: value);
                    break;
                  case 'edgeLabels':
                    updated = currentShape.copyWith(showEdgeLabels: value);
                    break;
                  case 'nameLabel':
                    updated = currentShape.copyWith(showNameLabel: value);
                    break;
                  case 'securityArea':
                    updated = currentShape.copyWith(showSecurityArea: value);
                    break;
                  default:
                    return;
                }
                
                await _shapeRepo.update(updated);
                setState(() {
                  _drawingShapes[shapeIndex] = updated;
                });
                setSheetState(() {}); // パネル内も更新
              },
              onSecurityAreaOffsetChanged: (offset) async {
                if (shapeIndex < 0) return;
                final updated = currentShape.copyWith(securityAreaOffset: offset);
                await _shapeRepo.update(updated);
                setState(() {
                  _drawingShapes[shapeIndex] = updated;
                });
                setSheetState(() {}); // パネル内も更新
              },
              onColorChange: (color) async {
                if (shapeIndex < 0) return;
                final updated = currentShape.copyWith(colorHex: color.toHex());
                await _shapeRepo.update(updated);
                setState(() {
                  _drawingShapes[shapeIndex] = updated;
                });
                setSheetState(() {}); // パネル内も更新
              },
              onRename: () async {
                Navigator.pop(dialogContext);
                final newName = await _showRenameDialog(currentShape.name);
                if (newName != null && newName.isNotEmpty && shapeIndex >= 0) {
                  final updated = currentShape.copyWith(name: newName);
                  await _shapeRepo.update(updated);
                  setState(() {
                    _drawingShapes[shapeIndex] = updated;
                  });
                  if (mounted) {
                    _showShapeActions(updated);
                  }
                }
              },
              onMoveToShape: () {
                Navigator.pop(dialogContext);
                final center = currentShape.center;
                if (center != null) {
                  _mapController.move(center, _mapController.camera.zoom);
                }
              },
              onDelete: () {
                Navigator.pop(dialogContext);
                _deleteShape(currentShape);
              },
              onClose: () => Navigator.pop(dialogContext),
            );
          },
        );
      },
    );
  }

  /// リネームダイアログを表示
  Future<String?> _showRenameDialog(String currentName) async {
    final controller = TextEditingController(text: currentName);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        title: const Text(
          'リネーム',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: '新しい名前',
            hintStyle: const TextStyle(color: AppColors.textHint),
            filled: true,
            fillColor: AppColors.backgroundSecondary,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('変更', style: TextStyle(color: AppColors.accentPrimary)),
          ),
        ],
      ),
    );
  }

  Future<void> _addMeasurementPoint(LatLng position) async {
    if (widget.missionId == null) return;
    if (_selectedMeasurementLayer == null) return;

    final point = MeasurementPoint(
      missionId: widget.missionId!,
      layerId: _selectedMeasurementLayer!.id,
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
        layerId: point.layerId,
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
    // レイヤーが選択されていない場合は計測を開始できない
    if (!_isMeasuring && _selectedMeasurementLayer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('計測レイヤーを選択または作成してください'),
          backgroundColor: AppColors.statusWarning,
        ),
      );
      // レイヤーパネルを表示
      setState(() => _showMeasurementLayerPanel = true);
      return;
    }

    setState(() => _isMeasuring = !_isMeasuring);

    if (_isMeasuring) {
      // 計測開始（自動モードのみ）
      _startAutoMeasurement();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '自動計測を開始しました（${_settingsService.measurementInterval}秒間隔）\nレイヤー: ${_selectedMeasurementLayer!.name}',
          ),
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

  /// 磁場センサーをキャリブレーション
  ///
  /// 現在の磁場値の平均を取って基準値として設定
  Future<void> _calibrateMagnetometer() async {
    // すでにキャリブレーション中なら何もしない
    if (_magnetometerService.isCalibrating) {
      return;
    }

    // センサーがリッスンしていなければ開始
    if (!_magnetometerService.isListening) {
      _magnetometerService.startListening();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('キャリブレーション中... 端末を動かさないでください'),
        backgroundColor: AppColors.statusWarning,
        duration: Duration(seconds: 3),
      ),
    );

    setState(() {}); // UIを更新（CAL...表示）

    try {
      final newReference = await _magnetometerService.startCalibration();
      
      if (mounted) {
        setState(() {}); // UIを更新（新しい基準値を表示）
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('キャリブレーション完了！基準値: ${newReference.toStringAsFixed(1)} μT'),
            backgroundColor: AppColors.statusSafe,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('キャリブレーションエラー: $e'),
            backgroundColor: AppColors.statusDanger,
          ),
        );
      }
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
    if (!_isMeasuring) return;
    await _addMeasurementPoint(_currentPosition);
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
      try {
        // データベースに保存
        final id = await _shapeRepo.insert(shape);
        final savedShape = shape.copyWith(id: id);

        setState(() => _drawingShapes.add(savedShape));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('図形「$name」を保存しました'),
              backgroundColor: AppColors.statusSafe,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('図形の保存に失敗しました: $e'),
              backgroundColor: AppColors.statusDanger,
            ),
          );
        }
      }
    }
  }

  /// 図形の表示/非表示を切り替え
  Future<void> _toggleShapeVisibility(DrawingShape shape) async {
    if (shape.id == null) return;

    try {
      final newVisibility = !shape.isVisible;
      await _shapeRepo.setVisibility(shape.id!, newVisibility);

      setState(() {
        final index = _drawingShapes.indexWhere((s) => s.id == shape.id);
        if (index != -1) {
          _drawingShapes[index] = shape.copyWith(isVisible: newVisibility);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('表示切り替えに失敗しました: $e'),
            backgroundColor: AppColors.statusDanger,
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

/// 図形編集パネルコンテンツ
class _ShapeEditPanelContent extends StatelessWidget {
  final DrawingShape shape;
  final void Function(String field, bool value) onToggleChanged;
  final void Function(double offset) onSecurityAreaOffsetChanged;
  final void Function(Color) onColorChange;
  final VoidCallback onRename;
  final VoidCallback onMoveToShape;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  const _ShapeEditPanelContent({
    required this.shape,
    required this.onToggleChanged,
    required this.onSecurityAreaOffsetChanged,
    required this.onColorChange,
    required this.onRename,
    required this.onMoveToShape,
    required this.onDelete,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: shape.color,
                    shape: shape.type == ShapeType.circle
                        ? BoxShape.circle
                        : BoxShape.rectangle,
                    borderRadius: shape.type != ShapeType.circle
                        ? BorderRadius.circular(3)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shape.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        shape.type.name.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),

            // 寸法情報
            const Text(
              '寸法情報',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _buildMeasurementInfo(),

            const SizedBox(height: 12),
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),

            // 表示設定
            const Text(
              '表示設定',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),

            // 図形表示 ON/OFF
            _buildToggleTile(
              icon: Icons.visibility,
              label: '図形表示',
              value: shape.isVisible,
              onChanged: (value) => onToggleChanged('visible', value),
            ),

            // 辺の長さ ON/OFF
            _buildToggleTile(
              icon: Icons.straighten,
              label: '辺の長さ表示',
              value: shape.showEdgeLabels,
              onChanged: (value) => onToggleChanged('edgeLabels', value),
            ),

            // ラベル表示 ON/OFF
            _buildToggleTile(
              icon: Icons.label,
              label: 'ラベル表示',
              value: shape.showNameLabel,
              onChanged: (value) => onToggleChanged('nameLabel', value),
            ),

            // 保安区域表示（ポリゴンのみ）
            if (shape.type == ShapeType.polygon) ...[
              const SizedBox(height: 12),
              const Divider(color: AppColors.border),
              const SizedBox(height: 8),

              const Text(
                '保安区域',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),

              // 保安区域表示 ON/OFF
              _buildToggleTile(
                icon: Icons.security,
                label: '保安区域表示',
                value: shape.showSecurityArea,
                onChanged: (value) => onToggleChanged('securityArea', value),
              ),

              // オフセット設定（保安区域ONの場合のみ）
              if (shape.showSecurityArea) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.space_bar,
                      size: 18,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'オフセット距離',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              // タップで直接入力可能
                              _SecurityAreaOffsetInput(
                                value: shape.securityAreaOffset,
                                onChanged: onSecurityAreaOffsetChanged,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          SliderTheme(
                            data: SliderThemeData(
                              activeTrackColor: AppColors.accentPrimary,
                              inactiveTrackColor: AppColors.border,
                              thumbColor: AppColors.accentPrimary,
                              overlayColor: AppColors.accentPrimary.withValues(alpha: 0.2),
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                              trackHeight: 4,
                            ),
                            child: Slider(
                              value: shape.securityAreaOffset.clamp(-500, 500),
                              min: -500,
                              max: 500,
                              divisions: 100,
                              onChanged: (value) => onSecurityAreaOffsetChanged(value),
                            ),
                          ),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '-500m (外側)',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 9,
                                  color: AppColors.textHint,
                                ),
                              ),
                              Text(
                                '0',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 9,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                '+500m (内側)',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 9,
                                  color: AppColors.textHint,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],

            const SizedBox(height: 12),
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),

            // カラー選択
            const Text(
              'カラー',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: AppColors.drawingColors.map((color) {
                final isSelected = shape.color.value == color.value;
                return GestureDetector(
                  onTap: () => onColorChange(color),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 12),
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),

            // アクションボタン
            const Text(
              'アクション',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.edit,
                    label: 'リネーム',
                    onTap: onRename,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.my_location,
                    label: '移動',
                    onTap: onMoveToShape,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.delete,
                    label: '削除',
                    onTap: onDelete,
                    isDanger: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String label,
    required bool value,
    required void Function(bool) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.accentPrimary,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDanger
              ? AppColors.statusDanger.withValues(alpha: 0.1)
              : AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDanger ? AppColors.statusDanger : AppColors.border,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: isDanger ? AppColors.statusDanger : AppColors.accentPrimary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDanger ? AppColors.statusDanger : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 寸法情報セクション
  Widget _buildMeasurementInfo() {
    final measurements = <Widget>[];

    switch (shape.type) {
      case ShapeType.polygon:
        // ポリゴン: 面積、外周距離、各辺の長さ
        final area = _calculatePolygonArea(shape.coordinates);
        final perimeter = _calculatePerimeter(shape.coordinates, isClosed: true);
        measurements.add(_buildMeasurementRow('面積', _formatArea(area)));
        measurements.add(_buildMeasurementRow('外周', _formatDistance(perimeter)));
        measurements.add(const SizedBox(height: 4));
        measurements.add(_buildEdgeLengths(shape.coordinates, isClosed: true));

      case ShapeType.polyline:
        // ポリライン: 総距離、各辺の長さ
        final totalDistance = _calculatePerimeter(shape.coordinates, isClosed: false);
        measurements.add(_buildMeasurementRow('総距離', _formatDistance(totalDistance)));
        measurements.add(const SizedBox(height: 4));
        measurements.add(_buildEdgeLengths(shape.coordinates, isClosed: false));

      case ShapeType.circle:
        // サークル: 面積、半径、直径、円周
        if (shape.radius != null) {
          final radius = shape.radius!;
          final area = 3.141592653589793 * radius * radius;
          final diameter = radius * 2;
          final circumference = 2 * 3.141592653589793 * radius;
          measurements.add(_buildMeasurementRow('半径', _formatDistance(radius)));
          measurements.add(_buildMeasurementRow('直径', _formatDistance(diameter)));
          measurements.add(_buildMeasurementRow('面積', _formatArea(area)));
          measurements.add(_buildMeasurementRow('円周', _formatDistance(circumference)));
        }
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: measurements,
      ),
    );
  }

  /// 寸法行
  Widget _buildMeasurementRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: shape.color,
            ),
          ),
        ],
      ),
    );
  }

  /// 各辺の長さ表示
  Widget _buildEdgeLengths(List<LatLng> points, {required bool isClosed}) {
    if (points.length < 2) return const SizedBox.shrink();

    final edges = <Widget>[];
    edges.add(const Text(
      '辺の長さ:',
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 10,
        color: AppColors.textHint,
      ),
    ));

    final edgeCount = isClosed ? points.length : points.length - 1;

    for (int i = 0; i < edgeCount; i++) {
      final from = points[i];
      final to = points[(i + 1) % points.length];
      final distance = _calculateDistance(from, to);
      edges.add(Text(
        '  ${i + 1}: ${_formatDistance(distance)}',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          color: shape.color.withValues(alpha: 0.8),
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: edges,
    );
  }

  /// 2点間の距離を計算（メートル）
  double _calculateDistance(LatLng from, LatLng to) {
    const earthRadius = 6371000.0;
    final lat1 = from.latitude * 3.141592653589793 / 180;
    final lat2 = to.latitude * 3.141592653589793 / 180;
    final dLat = (to.latitude - from.latitude) * 3.141592653589793 / 180;
    final dLng = (to.longitude - from.longitude) * 3.141592653589793 / 180;

    final a = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(lat1) * _cos(lat2) * _sin(dLng / 2) * _sin(dLng / 2);
    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));

    return earthRadius * c;
  }

  /// 外周距離を計算
  double _calculatePerimeter(List<LatLng> points, {required bool isClosed}) {
    if (points.length < 2) return 0;

    double perimeter = 0;
    for (int i = 0; i < points.length - 1; i++) {
      perimeter += _calculateDistance(points[i], points[i + 1]);
    }

    if (isClosed && points.length >= 3) {
      perimeter += _calculateDistance(points.last, points.first);
    }

    return perimeter;
  }

  /// ポリゴンの面積を計算（m²）
  double _calculatePolygonArea(List<LatLng> points) {
    if (points.length < 3) return 0;

    const earthRadius = 6371000.0;
    double area = 0;

    for (int i = 0; i < points.length; i++) {
      final j = (i + 1) % points.length;
      final xi = points[i].longitude * 3.141592653589793 / 180;
      final yi = points[i].latitude * 3.141592653589793 / 180;
      final xj = points[j].longitude * 3.141592653589793 / 180;
      final yj = points[j].latitude * 3.141592653589793 / 180;

      area += (xj - xi) * (2 + _sin(yi) + _sin(yj));
    }

    area = (area * earthRadius * earthRadius / 2).abs();
    return area;
  }

  /// 距離をフォーマット
  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(1)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
  }

  /// 面積をフォーマット
  String _formatArea(double sqMeters) {
    if (sqMeters < 10000) {
      return '${sqMeters.toStringAsFixed(1)} m²';
    } else {
      return '${(sqMeters / 10000).toStringAsFixed(2)} ha';
    }
  }

  // 三角関数ヘルパー（dart:mathを使用）
  double _sin(double x) => math.sin(x);
  double _cos(double x) => math.cos(x);
  double _sqrt(double x) => math.sqrt(x);
  double _atan2(double y, double x) => math.atan2(y, x);
}

/// 住所検索ダイアログウィジェット
class _SearchDialog extends StatefulWidget {
  final void Function(double lat, double lon) onLocationSelected;

  const _SearchDialog({required this.onLocationSelected});

  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String? _errorMessage;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final encodedQuery = Uri.encodeComponent(query);
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&limit=5&accept-language=ja',
        ),
        headers: {'User-Agent': 'MagPlotter/1.0'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _searchResults = data.map((item) => {
            'name': item['display_name'] as String,
            'lat': double.parse(item['lat'] as String),
            'lon': double.parse(item['lon'] as String),
          }).toList();
          _isSearching = false;
        });

        if (_searchResults.isEmpty) {
          setState(() => _errorMessage = '検索結果が見つかりませんでした');
        }
      } else {
        setState(() {
          _errorMessage = '検索に失敗しました (${response.statusCode})';
          _isSearching = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'ネットワークエラー: $e';
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.backgroundCard,
      title: const Row(
        children: [
          Icon(Icons.search, color: AppColors.accentPrimary, size: 20),
          SizedBox(width: 8),
          Text(
            '住所検索',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: '住所や場所名を入力',
                hintStyle: const TextStyle(color: AppColors.textHint),
                filled: true,
                fillColor: AppColors.backgroundSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: AppColors.accentPrimary),
                  onPressed: () => _performSearch(_searchController.text),
                ),
              ),
              onSubmitted: _performSearch,
            ),
            const SizedBox(height: 12),
            if (_isSearching)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: AppColors.accentPrimary),
              )
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppColors.statusWarning,
                    fontSize: 12,
                  ),
                ),
              )
            else if (_searchResults.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final result = _searchResults[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.location_on,
                        color: AppColors.accentPrimary,
                        size: 18,
                      ),
                      title: Text(
                        result['name'] as String,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        final lat = result['lat'] as double;
                        final lon = result['lon'] as double;
                        Navigator.of(context).pop();
                        widget.onLocationSelected(lat, lon);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'キャンセル',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// 計測レイヤー編集パネル
class _MeasurementLayerEditPanel extends StatefulWidget {
  final MeasurementLayer layer;
  final void Function(MeasurementLayer) onUpdate;
  final VoidCallback onDelete;

  const _MeasurementLayerEditPanel({
    required this.layer,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<_MeasurementLayerEditPanel> createState() => _MeasurementLayerEditPanelState();
}

class _MeasurementLayerEditPanelState extends State<_MeasurementLayerEditPanel> {
  late MeasurementLayer _layer;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _layer = widget.layer;
    _nameController = TextEditingController(text: _layer.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _updateLayer(MeasurementLayer updated) {
    setState(() => _layer = updated);
    widget.onUpdate(updated);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _layer.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _layer.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Text(
                        '計測レイヤー',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),

            // 名前変更
            const Text(
              'レイヤー名',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    if (_nameController.text.isNotEmpty) {
                      _updateLayer(_layer.copyWith(name: _nameController.text));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: const Text('変更', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),

            // 点群設定
            const Text(
              '点群設定',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),

            // 点サイズ
            Row(
              children: [
                const SizedBox(
                  width: 80,
                  child: Text(
                    '点サイズ',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _layer.pointSize,
                    min: 0.1,
                    max: 3.0,
                    divisions: 29,
                    activeColor: AppColors.accentPrimary,
                    onChanged: (value) {
                      _updateLayer(_layer.copyWith(pointSize: value));
                    },
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    '${_layer.pointSize.toStringAsFixed(1)} m',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),

            // ぼかし強度
            Row(
              children: [
                const SizedBox(
                  width: 80,
                  child: Text(
                    'ぼかし',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _layer.blurIntensity,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    activeColor: AppColors.accentPrimary,
                    onChanged: (value) {
                      _updateLayer(_layer.copyWith(blurIntensity: value));
                    },
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    '${(_layer.blurIntensity * 100).toInt()}%',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),

            // カラー選択
            const Text(
              'カラー',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: AppColors.drawingColors.map((color) {
                final isSelected = _layer.color.value == color.value;
                return GestureDetector(
                  onTap: () => _updateLayer(_layer.copyWith(color: color)),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),

            // 表示設定
            Row(
              children: [
                const Icon(Icons.visibility, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '表示',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
                Switch(
                  value: _layer.isVisible,
                  onChanged: (value) {
                    _updateLayer(_layer.copyWith(isVisible: value));
                  },
                  activeColor: AppColors.accentPrimary,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 削除ボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onDelete();
                },
                icon: const Icon(Icons.delete, size: 18),
                label: const Text('このレイヤーを削除'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.statusDanger.withValues(alpha: 0.2),
                  foregroundColor: AppColors.statusDanger,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 警戒区域詳細パネル
class _RestrictedAreaDetailPanel extends StatefulWidget {
  final RestrictedAreaLayer layer;
  final Function(RestrictedAreaLayer) onUpdate;

  const _RestrictedAreaDetailPanel({
    required this.layer,
    required this.onUpdate,
  });

  @override
  State<_RestrictedAreaDetailPanel> createState() => _RestrictedAreaDetailPanelState();
}

class _RestrictedAreaDetailPanelState extends State<_RestrictedAreaDetailPanel> {
  late RestrictedAreaLayer _layer;

  @override
  void initState() {
    super.initState();
    _layer = widget.layer;
  }

  void _updateLayer(RestrictedAreaLayer updatedLayer) {
    setState(() {
      _layer = updatedLayer;
    });
    widget.onUpdate(updatedLayer);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.border),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _layer.fillColor,
                      border: Border.all(color: _layer.strokeColor, width: 2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _layer.name,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),

            // 説明
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '概要',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accentPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _layer.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: AppColors.border, height: 1),

            // 法的根拠
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '法的根拠',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accentPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _layer.legalBasis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: AppColors.border, height: 1),

            // データ情報
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'データ情報',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accentPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow('データ年月', _layer.dataDate),
                  const SizedBox(height: 4),
                  _buildInfoRow('参照URL', _layer.referenceUrl),
                ],
              ),
            ),

            const Divider(color: AppColors.border, height: 1),

            // 表示設定
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '表示設定',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accentPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // 塗りつぶし色
                  _buildColorSelector(
                    label: '塗りつぶし色',
                    currentColor: Color(int.parse(_layer.fillColorHex, radix: 16)),
                    onColorChanged: (color) {
                      _updateLayer(_layer.copyWith(
                        fillColorHex: color.toHex(),
                      ));
                    },
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // 透明度スライダー
                  Row(
                    children: [
                      const Text(
                        '透明度',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: _layer.fillOpacity,
                          min: 0.0,
                          max: 1.0,
                          divisions: 10,
                          activeColor: AppColors.accentPrimary,
                          inactiveColor: AppColors.textHint,
                          onChanged: (value) {
                            _updateLayer(_layer.copyWith(fillOpacity: value));
                          },
                        ),
                      ),
                      Text(
                        '${(_layer.fillOpacity * 100).toInt()}%',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // 境界線表示
                  Row(
                    children: [
                      const Text(
                        '境界線を表示',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Switch(
                        value: _layer.showStroke,
                        activeColor: AppColors.accentPrimary,
                        onChanged: (value) {
                          _updateLayer(_layer.copyWith(showStroke: value));
                        },
                      ),
                    ],
                  ),
                  
                  if (_layer.showStroke) ...[
                    const SizedBox(height: 8),
                    
                    // 境界線色
                    _buildColorSelector(
                      label: '境界線色',
                      currentColor: Color(int.parse(_layer.strokeColorHex, radix: 16)),
                      onColorChanged: (color) {
                        _updateLayer(_layer.copyWith(
                          strokeColorHex: color.toHex(),
                        ));
                      },
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // 境界線の太さ
                    Row(
                      children: [
                        const Text(
                          '境界線の太さ',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: _layer.strokeWidth,
                            min: 0.5,
                            max: 5.0,
                            divisions: 9,
                            activeColor: AppColors.accentPrimary,
                            inactiveColor: AppColors.textHint,
                            onChanged: (value) {
                              _updateLayer(_layer.copyWith(strokeWidth: value));
                            },
                          ),
                        ),
                        Text(
                          '${_layer.strokeWidth.toStringAsFixed(1)}px',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textHint,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorSelector({
    required String label,
    required Color currentColor,
    required Function(Color) onColorChanged,
  }) {
    final colors = [
      const Color(0xFFFF6B6B), // 赤
      const Color(0xFFFF8C00), // オレンジ
      const Color(0xFFFFD700), // 黄色
      const Color(0xFF6B8EFF), // 青
      const Color(0xFF00CED1), // シアン
      const Color(0xFF32CD32), // 緑
      const Color(0xFFDA70D6), // ピンク
      const Color(0xFF9370DB), // 紫
    ];

    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            spacing: 8,
            children: colors.map((color) {
              final isSelected = currentColor.value == color.value;
              return GestureDetector(
                onTap: () => onColorChanged(color),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// 保安区域オフセット入力ウィジェット
///
/// タップで直接メートル値を入力可能
class _SecurityAreaOffsetInput extends StatelessWidget {
  final double value;
  final void Function(double) onChanged;

  const _SecurityAreaOffsetInput({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showInputDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.backgroundPrimary,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.accentPrimary.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value >= 0 ? '+${value.toInt()}' : '${value.toInt()}',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: value >= 0 ? AppColors.accentPrimary : AppColors.statusWarning,
              ),
            ),
            const SizedBox(width: 2),
            const Text(
              'm',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.edit,
              size: 12,
              color: AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }

  void _showInputDialog(BuildContext context) {
    final controller = TextEditingController(text: value.toInt().toString());
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        title: const Text(
          'オフセット距離入力',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              autofocus: true,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                suffixText: 'm',
                suffixStyle: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  color: AppColors.textHint,
                ),
                hintText: '-500〜+500',
                hintStyle: TextStyle(
                  color: AppColors.textHint.withValues(alpha: 0.5),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.accentPrimary, width: 2),
                ),
              ),
              onSubmitted: (text) {
                _applyValue(dialogContext, text);
              },
            ),
            const SizedBox(height: 8),
            const Text(
              '-500〜+500mの範囲で入力\n（+:内側、-:外側）',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'キャンセル',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => _applyValue(dialogContext, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentPrimary,
            ),
            child: const Text(
              '適用',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _applyValue(BuildContext dialogContext, String text) {
    final parsed = double.tryParse(text);
    if (parsed != null) {
      final clamped = parsed.clamp(-500.0, 500.0);
      onChanged(clamped);
    }
    Navigator.pop(dialogContext);
  }
}
