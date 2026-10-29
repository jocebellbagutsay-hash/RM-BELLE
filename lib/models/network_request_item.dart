/// Represents the current active network interface.
enum NetworkInterfaceType {
  wifi,
  cellular,
  offline,
  other;

  String get displayName {
    switch (this) {
      case NetworkInterfaceType.wifi:
        return 'Wi-Fi';
      case NetworkInterfaceType.cellular:
        return 'Cellular';
      case NetworkInterfaceType.offline:
        return 'Offline';
      case NetworkInterfaceType.other:
        return 'Other';
    }
  }

  bool get isOnline =>
      this == NetworkInterfaceType.wifi ||
      this == NetworkInterfaceType.cellular ||
      this == NetworkInterfaceType.other;
}

/// Lifecycle status for simulated long-running network requests.
enum RequestStatus {
  idle,
  running,
  queued,
  completed,
  failed;

  String get displayName {
    switch (this) {
      case RequestStatus.idle:
        return 'Idle';
      case RequestStatus.running:
        return 'In Progress';
      case RequestStatus.queued:
        return 'Queued (Awaiting Network)';
      case RequestStatus.completed:
        return 'Completed';
      case RequestStatus.failed:
        return 'Failed';
    }
  }
}

/// Represents a simulated continuous / long-running network request.
class NetworkRequestItem {
  NetworkRequestItem({
    required this.id,
    required this.title,
    required this.totalBytes,
    this.transferredBytes = 0,
    this.status = RequestStatus.idle,
    this.retryCount = 0,
    this.lastError,
    DateTime? createdAt,
    this.completedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String title;
  final int totalBytes;
  final int transferredBytes;
  final RequestStatus status;
  final int retryCount;
  final String? lastError;
  final DateTime createdAt;
  final DateTime? completedAt;

  double get progress {
    if (totalBytes <= 0) return 0.0;
    return (transferredBytes / totalBytes).clamp(0.0, 1.0);
  }

  bool get isDone => status == RequestStatus.completed;
  bool get isQueued => status == RequestStatus.queued;
  bool get isRunning => status == RequestStatus.running;

  NetworkRequestItem copyWith({
    String? id,
    String? title,
    int? totalBytes,
    int? transferredBytes,
    RequestStatus? status,
    int? retryCount,
    String? lastError,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return NetworkRequestItem(
      id: id ?? this.id,
      title: title ?? this.title,
      totalBytes: totalBytes ?? this.totalBytes,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

enum NetworkLogType {
  info,
  warning,
  success,
  error,
}

/// Log item representing connection state transitions, request enqueues, and auto-retries.
class NetworkLogEntry {
  NetworkLogEntry({
    required this.id,
    required this.message,
    required this.type,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final String id;
  final String message;
  final NetworkLogType type;
  final DateTime timestamp;
}
