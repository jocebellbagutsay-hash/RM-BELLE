enum NetworkHealth {
  excellent,
  fair,
  poor,
  degraded,
  unknown,
}

extension NetworkHealthExtension on NetworkHealth {
  String get displayName {
    switch (this) {
      case NetworkHealth.excellent:
        return 'Excellent';
      case NetworkHealth.fair:
        return 'Fair';
      case NetworkHealth.poor:
        return 'Poor';
      case NetworkHealth.degraded:
        return 'Degraded';
      case NetworkHealth.unknown:
        return 'Testing...';
    }
  }

  String get description {
    switch (this) {
      case NetworkHealth.excellent:
        return 'Connection supports maximum throughput (>10 Mbps). High-resolution multimedia is fully unthrottled.';
      case NetworkHealth.fair:
        return 'Connection is stable (2 - 10 Mbps). Balanced standard multimedia is enabled with adaptive compression.';
      case NetworkHealth.poor:
        return 'Bandwidth is heavily constrained (< 2 Mbps). High-res media is throttled to lightweight micro-thumbnails.';
      case NetworkHealth.degraded:
        return 'Heavy packet loss or extreme latency (>1000ms). Multimedia downloads are suspended in favor of zero-data placeholders.';
      case NetworkHealth.unknown:
        return 'Network diagnostic is currently running.';
    }
  }

  String get tierName {
    switch (this) {
      case NetworkHealth.excellent:
        return 'Tier 1: Excellent (>10 Mbps)';
      case NetworkHealth.fair:
        return 'Tier 2: Fair (2 - 10 Mbps)';
      case NetworkHealth.poor:
        return 'Tier 3: Poor (< 2 Mbps)';
      case NetworkHealth.degraded:
        return 'Tier 4: Degraded (Extreme Latency/Loss)';
      case NetworkHealth.unknown:
        return 'Evaluating Network Tier...';
    }
  }

  String get badgeLabel {
    switch (this) {
      case NetworkHealth.excellent:
        return '1080p ULTRA HD';
      case NetworkHealth.fair:
        return '720p BALANCED';
      case NetworkHealth.poor:
        return '240p MICRO-THUMBNAIL';
      case NetworkHealth.degraded:
        return 'ZERO-DATA PLACEHOLDER';
      case NetworkHealth.unknown:
        return 'PENDING';
    }
  }

  String get dataConsumption {
    switch (this) {
      case NetworkHealth.excellent:
        return '4.8 MB (100% Quality)';
      case NetworkHealth.fair:
        return '1.2 MB (60% Saved)';
      case NetworkHealth.poor:
        return '85 KB (98% Saved)';
      case NetworkHealth.degraded:
        return '0 KB (100% Blocked)';
      case NetworkHealth.unknown:
        return '0 KB';
    }
  }
}

class NetworkDiagnosticResult {
  final double idlePingMs;
  final double downloadMbps;
  final double downloadPingMs;
  final double uploadMbps;
  final double uploadPingMs;
  final NetworkHealth health;
  final DateTime timestamp;

  const NetworkDiagnosticResult({
    required this.idlePingMs,
    required this.downloadMbps,
    required this.downloadPingMs,
    required this.uploadMbps,
    required this.uploadPingMs,
    required this.health,
    required this.timestamp,
  });

  factory NetworkDiagnosticResult.empty() {
    return NetworkDiagnosticResult(
      idlePingMs: 0,
      downloadMbps: 0,
      downloadPingMs: 0,
      uploadMbps: 0,
      uploadPingMs: 0,
      health: NetworkHealth.unknown,
      timestamp: DateTime.now(),
    );
  }
}