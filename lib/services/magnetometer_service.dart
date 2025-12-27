/// MAG PLOTTER 磁気センサーサービス
///
/// 端末の磁気センサーからデータを取得し、磁場強度を計算する
/// sensors_plusパッケージを使用
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';
import '../core/constants/app_constants.dart';

/// 磁気センサーデータ
///
/// 3軸磁場値と計算された総磁場強度・ノイズ値・方位を保持
class MagnetometerData {
  /// X軸磁場 [μT]
  final double x;

  /// Y軸磁場 [μT]
  final double y;

  /// Z軸磁場 [μT]
  final double z;

  /// 総磁場強度 [μT]
  final double magnitude;

  /// ノイズ値（基準値との差） [μT]
  final double noise;

  /// 方位角（磁北からの角度）[度] 0-360
  /// 0=北, 90=東, 180=南, 270=西
  final double heading;

  /// タイムスタンプ
  final DateTime timestamp;

  /// ステータス
  final MagStatus status;

  MagnetometerData({
    required this.x,
    required this.y,
    required this.z,
    required this.magnitude,
    required this.noise,
    required this.heading,
    required this.timestamp,
    required this.status,
  });

  /// デフォルト値を生成
  factory MagnetometerData.initial() {
    return MagnetometerData(
      x: 0,
      y: 0,
      z: 0,
      magnitude: AppConstants.defaultReferenceMag,
      noise: 0,
      heading: 0,
      timestamp: DateTime.now(),
      status: MagStatus.unknown,
    );
  }

  /// 方位の方角名を取得（8方位）
  String get headingDirection {
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

  /// 方位のフォーマット済み文字列
  String get formattedHeading => '${heading.toStringAsFixed(0)}°';

  @override
  String toString() {
    return 'MagnetometerData(mag: ${magnitude.toStringAsFixed(1)}μT, '
        'noise: ${noise.toStringAsFixed(1)}μT, heading: $formattedHeading, status: $status)';
  }
}

/// 磁場ステータス
enum MagStatus {
  /// 安全（ノイズ < 安全閾値）
  safe,

  /// 警告（安全閾値 ≤ ノイズ < 危険閾値）
  warning,

  /// 危険（ノイズ ≥ 危険閾値）
  danger,

  /// 不明（計測前）
  unknown,
}

/// 磁気センサーサービス
///
/// センサーからのデータストリームを管理し、磁場強度・ノイズ値を計算
class MagnetometerService {
  /// センサーイベントのサブスクリプション
  StreamSubscription<MagnetometerEvent>? _subscription;

  /// データストリームコントローラー
  final _dataController = StreamController<MagnetometerData>.broadcast();

  /// 基準磁場値 [μT]
  double _referenceMag = AppConstants.defaultReferenceMag;

  /// 安全閾値 [μT]
  double _safeThreshold = AppConstants.defaultSafeThreshold;

  /// 危険閾値 [μT]
  double _dangerThreshold = AppConstants.defaultDangerThreshold;

  /// 最新の磁場データ
  MagnetometerData _latestData = MagnetometerData.initial();

  /// センサーが利用可能かどうか
  bool _isAvailable = false;

  /// 計測中かどうか
  bool _isListening = false;

  /// キャリブレーション用のサンプルリスト
  final List<double> _calibrationSamples = [];

  /// キャリブレーション中かどうか
  bool _isCalibrating = false;

  /// キャリブレーションに必要なサンプル数
  static const int _calibrationSampleCount = 20;

  /// データストリーム
  Stream<MagnetometerData> get dataStream => _dataController.stream;

  /// 最新のデータ
  MagnetometerData get latestData => _latestData;

  /// センサーが利用可能か
  bool get isAvailable => _isAvailable;

  /// 計測中か
  bool get isListening => _isListening;

  /// キャリブレーション中か
  bool get isCalibrating => _isCalibrating;

  /// 基準磁場値
  double get referenceMag => _referenceMag;

  /// 安全閾値
  double get safeThreshold => _safeThreshold;

  /// 危険閾値
  double get dangerThreshold => _dangerThreshold;

  /// サービスを初期化
  ///
  /// センサーの利用可能性を確認
  Future<bool> initialize() async {
    try {
      // センサーイベントを一時的に購読してテスト
      final completer = Completer<bool>();
      
      final testSubscription = magnetometerEventStream().listen(
        (event) {
          if (!completer.isCompleted) {
            _isAvailable = true;
            completer.complete(true);
          }
        },
        onError: (error) {
          if (!completer.isCompleted) {
            _isAvailable = false;
            completer.complete(false);
          }
        },
      );

      // タイムアウト設定（2秒）
      Future.delayed(const Duration(seconds: 2), () {
        if (!completer.isCompleted) {
          _isAvailable = false;
          completer.complete(false);
        }
      });

      final result = await completer.future;
      await testSubscription.cancel();
      
      return result;
    } catch (e) {
      _isAvailable = false;
      return false;
    }
  }

  /// 閾値を設定
  ///
  /// [referenceMag] 基準磁場値
  /// [safeThreshold] 安全閾値
  /// [dangerThreshold] 危険閾値
  void setThresholds({
    double? referenceMag,
    double? safeThreshold,
    double? dangerThreshold,
  }) {
    if (referenceMag != null) _referenceMag = referenceMag;
    if (safeThreshold != null) _safeThreshold = safeThreshold;
    if (dangerThreshold != null) _dangerThreshold = dangerThreshold;
  }

  /// キャリブレーションを開始
  ///
  /// 20サンプルの平均を取って基準値として設定
  /// 完了時に新しい基準値を返すFutureを返す
  Future<double> startCalibration() async {
    if (!_isListening) {
      throw Exception('キャリブレーション前にセンサーを開始してください');
    }

    _isCalibrating = true;
    _calibrationSamples.clear();

    // サンプルが集まるまで待機
    final completer = Completer<double>();

    late StreamSubscription<MagnetometerData> subscription;
    subscription = dataStream.listen((data) {
      if (_isCalibrating) {
        _calibrationSamples.add(data.magnitude);

        if (_calibrationSamples.length >= _calibrationSampleCount) {
          // 平均を計算
          final average = _calibrationSamples.reduce((a, b) => a + b) /
              _calibrationSamples.length;

          // 基準値を更新
          _referenceMag = average;
          _isCalibrating = false;
          _calibrationSamples.clear();

          subscription.cancel();
          completer.complete(average);
        }
      }
    });

    return completer.future;
  }

  /// キャリブレーションをキャンセル
  void cancelCalibration() {
    _isCalibrating = false;
    _calibrationSamples.clear();
  }

  /// 現在の磁場値を即座に基準値として設定
  void setCurrentAsReference() {
    if (_latestData.magnitude > 0) {
      _referenceMag = _latestData.magnitude;
    }
  }

  /// センサーの購読を開始
  ///
  /// [samplingPeriod] サンプリング間隔（デフォルト: 20ms = 50Hz）
  void startListening({Duration samplingPeriod = const Duration(milliseconds: 20)}) {
    if (_isListening) return;

    _subscription = magnetometerEventStream(samplingPeriod: samplingPeriod).listen(
      _onMagnetometerEvent,
      onError: _onError,
    );

    _isListening = true;
  }

  /// センサーの購読を停止
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _isListening = false;
  }

  /// センサーイベントの処理
  void _onMagnetometerEvent(MagnetometerEvent event) {
    // iOSのsensors_plusはマイクロテスラ(μT)を返すが、
    // 一部のデバイスでは異なるスケールの可能性がある
    // デバッグ: print('MAG RAW: x=${event.x}, y=${event.y}, z=${event.z}');
    
    // 総磁場強度を計算: √(x² + y² + z²)
    final magnitude = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    // ノイズ値を計算: |磁場強度 - 基準値|
    final noise = (magnitude - _referenceMag).abs();

    // ステータスを判定
    final status = _calculateStatus(noise);

    // 方位を計算: atan2(y, x) を使用
    // 注意: 端末の向きによって軸の解釈が異なる
    // iOSでは画面を上にした状態で、+Xが東、+Yが北
    double heading = math.atan2(event.x, event.y) * 180 / math.pi;
    // 0-360の範囲に正規化
    if (heading < 0) heading += 360;

    // データを更新
    _latestData = MagnetometerData(
      x: event.x,
      y: event.y,
      z: event.z,
      magnitude: magnitude,
      noise: noise,
      heading: heading,
      timestamp: DateTime.now(),
      status: status,
    );

    // ストリームに送信
    _dataController.add(_latestData);
  }

  /// ノイズ値からステータスを計算
  MagStatus _calculateStatus(double noise) {
    if (noise < _safeThreshold) {
      return MagStatus.safe;
    } else if (noise < _dangerThreshold) {
      return MagStatus.warning;
    } else {
      return MagStatus.danger;
    }
  }

  /// エラー処理
  void _onError(dynamic error) {
    // エラー時はunknownステータスを設定
    _latestData = MagnetometerData(
      x: 0,
      y: 0,
      z: 0,
      magnitude: 0,
      noise: 0,
      heading: 0,
      timestamp: DateTime.now(),
      status: MagStatus.unknown,
    );
    _dataController.add(_latestData);
  }

  /// リソースを解放
  void dispose() {
    stopListening();
    _dataController.close();
  }
}

