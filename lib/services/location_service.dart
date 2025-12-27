/// MAG PLOTTER 位置情報サービス
///
/// GPS/GNSSから現在位置を取得し、計測ポイントの位置情報を管理
/// geolocatorパッケージを使用
library;

import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants/app_constants.dart';

/// 位置情報データ
class LocationData {
  /// 緯度
  final double latitude;

  /// 経度
  final double longitude;

  /// 高度 [m]
  final double altitude;

  /// 精度 [m]
  final double accuracy;

  /// タイムスタンプ
  final DateTime timestamp;

  /// LatLngオブジェクトを取得
  LatLng get latLng => LatLng(latitude, longitude);

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.accuracy,
    required this.timestamp,
  });

  /// デフォルト位置（東京）を生成
  factory LocationData.defaultLocation() {
    return LocationData(
      latitude: AppConstants.defaultLatitude,
      longitude: AppConstants.defaultLongitude,
      altitude: 0,
      accuracy: 0,
      timestamp: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'LocationData(lat: ${latitude.toStringAsFixed(6)}, '
        'lng: ${longitude.toStringAsFixed(6)}, accuracy: ${accuracy.toStringAsFixed(1)}m)';
  }
}

/// 位置情報サービス
///
/// GPS/GNSSからの位置情報取得と権限管理を行う
class LocationService {
  /// 位置情報ストリームのサブスクリプション
  StreamSubscription<Position>? _subscription;

  /// 位置情報ストリームコントローラー
  final _locationController = StreamController<LocationData>.broadcast();

  /// 最新の位置情報
  LocationData _latestLocation = LocationData.defaultLocation();

  /// サービスが利用可能か
  bool _isAvailable = false;

  /// 位置情報を取得中か
  bool _isTracking = false;

  /// 位置情報ストリーム
  Stream<LocationData> get locationStream => _locationController.stream;

  /// 最新の位置情報
  LocationData get latestLocation => _latestLocation;

  /// サービスが利用可能か
  bool get isAvailable => _isAvailable;

  /// 位置情報を取得中か
  bool get isTracking => _isTracking;

  /// サービスを初期化し、権限を確認
  ///
  /// 戻り値: 権限が許可されていればtrue
  Future<bool> initialize() async {
    try {
      // 位置情報サービスが有効か確認
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _isAvailable = false;
        return false;
      }

      // 権限を確認
      var permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        // 権限をリクエスト
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _isAvailable = false;
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // 永久に拒否されている
        _isAvailable = false;
        return false;
      }

      _isAvailable = true;
      return true;
    } catch (e) {
      _isAvailable = false;
      return false;
    }
  }

  /// 現在位置を一度だけ取得
  Future<LocationData?> getCurrentLocation() async {
    if (!_isAvailable) {
      final initialized = await initialize();
      if (!initialized) return null;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      _latestLocation = _positionToLocationData(position);
      return _latestLocation;
    } catch (e) {
      return null;
    }
  }

  /// 位置情報の追跡を開始
  ///
  /// [distanceFilter] 位置更新の最小距離 [m]（デフォルト: 1m）
  Future<bool> startTracking({double distanceFilter = 1}) async {
    if (_isTracking) return true;

    if (!_isAvailable) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    try {
      _subscription = Geolocator.getPositionStream(
        locationSettings: AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 1,
          activityType: ActivityType.fitness,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
        ),
      ).listen(
        _onPositionUpdate,
        onError: _onError,
      );

      _isTracking = true;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 位置情報の追跡を停止
  void stopTracking() {
    _subscription?.cancel();
    _subscription = null;
    _isTracking = false;
  }

  /// 位置更新時の処理
  void _onPositionUpdate(Position position) {
    _latestLocation = _positionToLocationData(position);
    _locationController.add(_latestLocation);
  }

  /// Positionを LocationDataに変換
  LocationData _positionToLocationData(Position position) {
    return LocationData(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      accuracy: position.accuracy,
      timestamp: DateTime.now(),
    );
  }

  /// エラー処理
  void _onError(dynamic error) {
    // エラー時はデフォルト位置を設定
    _latestLocation = LocationData.defaultLocation();
    _locationController.add(_latestLocation);
  }

  /// 2点間の距離を計算 [m]
  double calculateDistance(LatLng from, LatLng to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  /// 2点間の方位を計算 [度]
  double calculateBearing(LatLng from, LatLng to) {
    return Geolocator.bearingBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  /// リソースを解放
  void dispose() {
    stopTracking();
    _locationController.close();
  }
}

