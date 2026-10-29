import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/network_diagnostic_result.dart';
import '../services/network_diagnostic_service.dart';

class NetworkDiagnosticProvider extends ChangeNotifier {
  final NetworkDiagnosticService _service;

  NetworkDiagnosticProvider({
    NetworkDiagnosticService? service,
  }) : _service = service ?? NetworkDiagnosticService();

  NetworkDiagnosticResult _result =
      NetworkDiagnosticResult.empty();

  bool _isTesting = false;

  String _currentStep = 'Ready to test';

  Timer? _timer;

  bool _isMonitoring = false;
  int _countdown = 0;
  int _monitoringIntervalSeconds = 10;

  NetworkDiagnosticResult get result => _result;

  NetworkHealth get health => _result.health;

  bool get isTesting => _isTesting;

  bool get isMonitoring => _isMonitoring;

  int get countdown => _countdown;

  int get monitoringIntervalSeconds => _monitoringIntervalSeconds;

  String get currentStep => _currentStep;

  /// Starts automatic recurring network diagnostics with a live ticker.
  void startMonitoring({int intervalSeconds = 10}) {
    if (_isMonitoring) return;

    _isMonitoring = true;
    _monitoringIntervalSeconds = intervalSeconds;
    _countdown = intervalSeconds;
    notifyListeners();

    // Trigger an immediate diagnostic test
    runDiagnostic();

    // Periodic 1-second countdown ticker for active automatic testing
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isTesting) return;

      if (_countdown > 1) {
        _countdown--;
        notifyListeners();
      } else {
        _countdown = _monitoringIntervalSeconds;
        notifyListeners();
        runDiagnostic();
      }
    });
  }

  /// Stops automatic recurring diagnostics.
  void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
    _isMonitoring = false;
    _countdown = 0;
    notifyListeners();
  }

  Future<void> runDiagnostic() async {
    if (_isTesting) return;

    _isTesting = true;
    notifyListeners();

    try {
      _currentStep = 'Measuring idle ping...';
      notifyListeners();

      final idlePing = await _service.measurePing();

      _currentStep =
          'Measuring download bandwidth + download ping...';
      notifyListeners();

      final download = await _service.measureDownload();

      _currentStep =
          'Measuring upload bandwidth + upload ping...';
      notifyListeners();

      final upload = await _service.measureUpload();

      NetworkHealth health = _service.classifyHealth(
        idlePing: idlePing,
        downloadMbps: download.mbps,
        downloadPing: download.pingMs,
        uploadMbps: upload.mbps,
        uploadPing: upload.pingMs,
      );

      _result = NetworkDiagnosticResult(
        idlePingMs: idlePing,
        downloadMbps: download.mbps,
        downloadPingMs: download.pingMs,
        uploadMbps: upload.mbps,
        uploadPingMs: upload.pingMs,
        health: health,
        timestamp: DateTime.now(),
      );

      _currentStep = 'Diagnostic complete';
    } catch (e) {
      _result = NetworkDiagnosticResult(
        idlePingMs: double.infinity,
        downloadMbps: 0,
        downloadPingMs: double.infinity,
        uploadMbps: 0,
        uploadPingMs: double.infinity,
        health: NetworkHealth.degraded,
        timestamp: DateTime.now(),
      );

      _currentStep = 'Diagnostic failed';
    } finally {
      _isTesting = false;
      notifyListeners();
    }
  }


  @visibleForTesting
  void setHealthForTesting(NetworkHealth health) {
    _result = NetworkDiagnosticResult(
      idlePingMs: health == NetworkHealth.degraded ? double.infinity : 20.0,
      downloadMbps: health == NetworkHealth.excellent
          ? 25.0
          : health == NetworkHealth.fair
              ? 5.0
              : health == NetworkHealth.poor
                  ? 1.0
                  : 0.0,
      downloadPingMs: health == NetworkHealth.degraded ? 1200.0 : 25.0,
      uploadMbps: 5.0,
      uploadPingMs: 30.0,
      health: health,
      timestamp: DateTime.now(),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    stopMonitoring();
    _service.dispose();
    super.dispose();
  }
}