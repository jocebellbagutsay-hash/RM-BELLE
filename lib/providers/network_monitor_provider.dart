import 'dart:async';
import 'package:flutter/material.dart';

import '../models/network_request_item.dart';
import '../services/network_monitor_service.dart';

/// Custom exception thrown when a simulated network handover or drop occurs.
class NetworkHandoverException implements Exception {
  NetworkHandoverException(this.message);
  final String message;

  @override
  String toString() => 'NetworkHandoverException: $message';
}

/// Provider managing active network interface streams, simulated long-running
/// network requests, request queuing, and graceful auto-recovery upon reconnection.
class NetworkMonitorProvider extends ChangeNotifier {
  NetworkMonitorProvider({
    NetworkMonitorService? service,
    NetworkInterfaceType initialInterface = NetworkInterfaceType.wifi,
  })  : _currentInterface = initialInterface,
        _service = service ?? NetworkMonitorService() {
    _init();
  }

  final NetworkMonitorService _service;
  StreamSubscription<NetworkInterfaceType>? _interfaceSubscription;

  NetworkInterfaceType _currentInterface;
  bool _isProcessingQueue = false;

  final List<NetworkRequestItem> _requests = [];
  final List<NetworkLogEntry> _eventLogs = [];

  // Getters
  NetworkInterfaceType get currentInterface => _currentInterface;
  bool get isOnline => _currentInterface.isOnline;
  bool get isSimulationMode => _service.isSimulationMode;
  List<NetworkRequestItem> get requests => List.unmodifiable(_requests);
  List<NetworkLogEntry> get eventLogs => List.unmodifiable(_eventLogs);
  int get queuedCount =>
      _requests.where((r) => r.status == RequestStatus.queued).length;
  int get runningCount =>
      _requests.where((r) => r.status == RequestStatus.running).length;
  int get completedCount =>
      _requests.where((r) => r.status == RequestStatus.completed).length;

  Future<void> _init() async {
    // Subscribe to stream changes
    _interfaceSubscription = _service.onInterfaceChanged.listen((newInterface) {
      _handleInterfaceChange(newInterface);
    });

    if (!_service.isSimulationMode) {
      try {
        final current = await _service.checkCurrentInterface();
        if (_currentInterface != current) {
          _handleInterfaceChange(current);
        } else {
          _addLog(
            'Initial network state: ${_currentInterface.displayName}',
            _currentInterface.isOnline
                ? NetworkLogType.info
                : NetworkLogType.warning,
          );
        }
      } catch (_) {}
    } else {
      _addLog(
        'Initial network state: ${_currentInterface.displayName}',
        _currentInterface.isOnline
            ? NetworkLogType.info
            : NetworkLogType.warning,
      );
    }
    notifyListeners();
  }

  void _handleInterfaceChange(NetworkInterfaceType newInterface) {
    if (_currentInterface == newInterface) return;

    final previous = _currentInterface;
    _currentInterface = newInterface;

    _addLog(
      'Network handover: ${previous.displayName} ➔ ${newInterface.displayName}',
      newInterface.isOnline ? NetworkLogType.info : NetworkLogType.warning,
    );

    // If connection dropped, queue any running requests safely
    if (!newInterface.isOnline) {
      _pauseRunningRequestsToQueue();
    } else if (!previous.isOnline && newInterface.isOnline) {
      // Re-established stable connection (Wi-Fi or Cellular): trigger graceful recovery
      _addLog(
        'Stable connection re-established (${newInterface.displayName}). Resuming queued requests...',
        NetworkLogType.success,
      );
      _processQueue();
    }

    notifyListeners();
  }

  void _pauseRunningRequestsToQueue() {
    for (int i = 0; i < _requests.length; i++) {
      final req = _requests[i];
      if (req.status == RequestStatus.running) {
        _requests[i] = req.copyWith(
          status: RequestStatus.queued,
          retryCount: req.retryCount + 1,
          lastError: 'Interrupted by network disconnect / handover.',
        );
        _addLog(
          'Request "${req.title}" intercepted and queued safely (retry #${req.retryCount + 1}).',
          NetworkLogType.warning,
        );
      }
    }
  }

  /// Initiates a continuous or long-running simulated network request.
  Future<void> enqueueRequest({
    String? title,
    int totalBytes = 5000000,
    int chunks = 5,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final requestTitle = title ?? 'Dataset Sync #${_requests.length + 1}';

    final newItem = NetworkRequestItem(
      id: id,
      title: requestTitle,
      totalBytes: totalBytes,
      status: isOnline ? RequestStatus.idle : RequestStatus.queued,
      lastError: isOnline ? null : 'Queued: No active connection.',
    );

    _requests.insert(0, newItem);
    _addLog(
      'New request registered: "$requestTitle" (${(totalBytes / 1000000).toStringAsFixed(1)} MB)',
      NetworkLogType.info,
    );
    notifyListeners();

    if (isOnline) {
      _executeRequest(newItem.id, chunks: chunks);
    } else {
      _addLog(
        'Offline: Request "$requestTitle" queued awaiting connection.',
        NetworkLogType.warning,
      );
    }
  }

  /// Executes or resumes a simulated chunked network request.
  Future<void> _executeRequest(String id, {int chunks = 5}) async {
    final index = _requests.indexWhere((r) => r.id == id);
    if (index == -1) return;

    var req = _requests[index];
    _requests[index] = req.copyWith(
      status: RequestStatus.running,
      lastError: null,
    );
    notifyListeners();

    try {
      final chunkSize = (req.totalBytes / chunks).round();
      var currentBytes = req.transferredBytes;

      while (currentBytes < req.totalBytes) {
        // Yield execution to simulate network transfer latency
        await Future<void>.delayed(const Duration(milliseconds: 300));

        // Catch connection drops or handovers during IP migration
        if (!isOnline) {
          throw NetworkHandoverException(
            'Connection lost during handover/migration.',
          );
        }

        // Verify request was not cancelled
        final currentIndex = _requests.indexWhere((r) => r.id == id);
        if (currentIndex == -1) return;

        currentBytes = (currentBytes + chunkSize).clamp(0, req.totalBytes);
        _requests[currentIndex] = _requests[currentIndex].copyWith(
          transferredBytes: currentBytes,
        );
        notifyListeners();
      }

      // Completed successfully
      final finalIndex = _requests.indexWhere((r) => r.id == id);
      if (finalIndex != -1) {
        _requests[finalIndex] = _requests[finalIndex].copyWith(
          status: RequestStatus.completed,
          transferredBytes: req.totalBytes,
          completedAt: DateTime.now(),
        );
        _addLog(
          'Completed request: "${req.title}" successfully!',
          NetworkLogType.success,
        );
        notifyListeners();
      }
    } on NetworkHandoverException catch (e) {
      // Gracefully catch the error and queue the request instead of crashing
      final catchIndex = _requests.indexWhere((r) => r.id == id);
      if (catchIndex != -1) {
        _requests[catchIndex] = _requests[catchIndex].copyWith(
          status: RequestStatus.queued,
          retryCount: _requests[catchIndex].retryCount + 1,
          lastError: e.message,
        );
        _addLog(
          'Caught network loss for "${req.title}". Queued for recovery.',
          NetworkLogType.warning,
        );
        notifyListeners();
      }
    } catch (e) {
      // General safety catch to avoid crashing
      final catchIndex = _requests.indexWhere((r) => r.id == id);
      if (catchIndex != -1) {
        _requests[catchIndex] = _requests[catchIndex].copyWith(
          status: RequestStatus.queued,
          lastError: 'Unexpected error: $e',
        );
        notifyListeners();
      }
    }
  }

  /// Automatically resumes all queued requests sequentially.
  Future<void> _processQueue() async {
    if (_isProcessingQueue || !isOnline) return;
    _isProcessingQueue = true;

    try {
      final queuedIds = _requests
          .where((r) => r.status == RequestStatus.queued)
          .map((r) => r.id)
          .toList();

      for (final id in queuedIds) {
        if (!isOnline) break;
        await _executeRequest(id);
      }
    } finally {
      _isProcessingQueue = false;
    }
  }

  /// Manual trigger to re-attempt queued requests.
  Future<void> retryQueuedRequests() async {
    if (!isOnline) {
      _addLog('Cannot retry: Network is currently offline.', NetworkLogType.error);
      return;
    }
    _addLog('Manual queue retry triggered.', NetworkLogType.info);
    await _processQueue();
  }

  /// Simulation control: manually set simulated network interface.
  void simulateInterface(NetworkInterfaceType type) {
    _service.simulateNetworkInterface(type);
    _handleInterfaceChange(type);
  }

  /// Simulation control: return to physical device hardware monitoring.
  void useDeviceNetwork() {
    _service.setSimulationMode(false);
    _addLog('Restored real-device hardware listener.', NetworkLogType.info);
  }

  void clearCompleted() {
    _requests.removeWhere((r) => r.status == RequestStatus.completed);
    notifyListeners();
  }

  void clearAllRequests() {
    _requests.clear();
    _addLog('Request queue cleared.', NetworkLogType.info);
    notifyListeners();
  }

  void _addLog(String message, NetworkLogType type) {
    _eventLogs.insert(
      0,
      NetworkLogEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        message: message,
        type: type,
      ),
    );
    if (_eventLogs.length > 50) {
      _eventLogs.removeLast();
    }
  }

  @override
  void dispose() {
    _interfaceSubscription?.cancel();
    _service.dispose();
    super.dispose();
  }
}
