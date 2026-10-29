import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/network_request_item.dart';

/// Service responsible for querying and subscribing to network interface state changes.
/// Supports both live device network hardware and interactive simulation mode.
class NetworkMonitorService {
  NetworkMonitorService({
    Connectivity? connectivity,
    bool isSimulationMode = false,
    NetworkInterfaceType simulatedType = NetworkInterfaceType.wifi,
  })  : _connectivity = connectivity ?? Connectivity(),
        _isSimulationMode = isSimulationMode,
        _simulatedType = simulatedType {
    _initDeviceStream();
  }

  final Connectivity _connectivity;
  final StreamController<NetworkInterfaceType> _interfaceController =
      StreamController<NetworkInterfaceType>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _deviceSubscription;

  bool _isSimulationMode;
  NetworkInterfaceType _simulatedType;

  /// Broadcast stream emitting real-time network interface updates.
  Stream<NetworkInterfaceType> get onInterfaceChanged =>
      _interfaceController.stream;

  bool get isSimulationMode => _isSimulationMode;
  NetworkInterfaceType get simulatedType => _simulatedType;

  void _initDeviceStream() {
    if (_isSimulationMode) return;

    try {
      _deviceSubscription = _connectivity.onConnectivityChanged.listen(
        (results) {
          if (!_isSimulationMode) {
            final mapped = mapConnectivityResults(results);
            _interfaceController.add(mapped);
          }
        },
        onError: (_) {
          if (!_isSimulationMode) {
            _interfaceController.add(NetworkInterfaceType.offline);
          }
        },
      );
    } catch (_) {
      // Graceful fallback in test/mock environments
    }
  }

  /// Query the current active network interface.
  Future<NetworkInterfaceType> checkCurrentInterface() async {
    if (_isSimulationMode) {
      return _simulatedType;
    }

    try {
      final results = await _connectivity.checkConnectivity();
      return mapConnectivityResults(results);
    } catch (_) {
      return NetworkInterfaceType.offline;
    }
  }

  /// Enables or disables simulation mode.
  void setSimulationMode(bool enabled, {NetworkInterfaceType? initialType}) {
    _isSimulationMode = enabled;
    if (enabled) {
      if (initialType != null) {
        _simulatedType = initialType;
      }
      _interfaceController.add(_simulatedType);
    } else {
      checkCurrentInterface().then((type) {
        _interfaceController.add(type);
      });
    }
  }

  /// Sets a simulated network interface and emits it to the stream.
  void simulateNetworkInterface(NetworkInterfaceType type) {
    _isSimulationMode = true;
    _simulatedType = type;
    _interfaceController.add(type);
  }

  /// Maps `List<ConnectivityResult>` from connectivity_plus to `NetworkInterfaceType`.
  static NetworkInterfaceType mapConnectivityResults(
      List<ConnectivityResult> results) {
    if (results.isEmpty) {
      return NetworkInterfaceType.offline;
    }

    // Prioritize active Wi-Fi
    if (results.contains(ConnectivityResult.wifi)) {
      return NetworkInterfaceType.wifi;
    }

    // Next prioritize active Cellular
    if (results.contains(ConnectivityResult.mobile)) {
      return NetworkInterfaceType.cellular;
    }

    // Ethernet, VPN, Bluetooth, or other
    if (results.contains(ConnectivityResult.ethernet) ||
        results.contains(ConnectivityResult.vpn) ||
        results.contains(ConnectivityResult.other)) {
      return NetworkInterfaceType.other;
    }

    // Default to offline when only 'none' is present
    return NetworkInterfaceType.offline;
  }

  void dispose() {
    _deviceSubscription?.cancel();
    _interfaceController.close();
  }
}
