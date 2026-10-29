import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/network_diagnostic_result.dart';

class NetworkDiagnosticService {
  static const String _testUrl =
      'https://speed.cloudflare.com/cdn-cgi/trace';

  // Optimized to 1 MB download: produces accurate Mbps instantly (< 1s)
  static const String _downloadUrl =
      'https://speed.cloudflare.com/__down?bytes=1000000';

  static const String _uploadUrl =
      'https://speed.cloudflare.com/__up';

  final http.Client _client;

  NetworkDiagnosticService({http.Client? client})
      : _client = client ?? http.Client();

  /// Measures a simple HTTP round-trip latency.
  Future<double> measurePing() async {
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _client
          .get(Uri.parse(_testUrl))
          .timeout(const Duration(seconds: 5));

      stopwatch.stop();

      if (response.statusCode >= 200 && response.statusCode < 400) {
        return stopwatch.elapsedMicroseconds / 1000;
      }

      return double.infinity;
    } catch (_) {
      stopwatch.stop();
      return double.infinity;
    }
  }

  /// Measures download bandwidth while another ping is measured concurrently.
  Future<BandwidthResult> measureDownload() async {
    final stopwatch = Stopwatch()..start();

    double concurrentPing = double.infinity;

    final pingFuture = _measureConcurrentPing(
      onResult: (value) {
        concurrentPing = value;
      },
    );

    try {
      final response = await _client
          .get(Uri.parse(_downloadUrl))
          .timeout(const Duration(seconds: 8));

      stopwatch.stop();

      await pingFuture;

      if (response.statusCode < 200 || response.statusCode >= 400) {
        return BandwidthResult(
          mbps: 0,
          pingMs: concurrentPing,
        );
      }

      final bytes = response.bodyBytes.length;

      final seconds =
          stopwatch.elapsedMicroseconds / Duration.microsecondsPerSecond;

      if (seconds <= 0 || bytes <= 0) {
        return BandwidthResult(
          mbps: 0,
          pingMs: concurrentPing,
        );
      }

      final megabits = (bytes * 8) / 1000000;
      final mbps = megabits / seconds;

      return BandwidthResult(
        mbps: mbps,
        pingMs: concurrentPing,
      );
    } catch (_) {
      stopwatch.stop();
      await pingFuture;

      return BandwidthResult(
        mbps: 0,
        pingMs: concurrentPing,
      );
    }
  }

  /// Measures upload bandwidth while another ping is measured concurrently.
  Future<BandwidthResult> measureUpload() async {
    // 256 KB upload payload: optimal for rapid measurement without mobile stalling
    final data = Uint8List(256 * 1024);

    final stopwatch = Stopwatch()..start();

    double concurrentPing = double.infinity;

    final pingFuture = _measureConcurrentPing(
      onResult: (value) {
        concurrentPing = value;
      },
    );

    try {
      final response = await _client
          .post(
            Uri.parse(_uploadUrl),
            body: data,
            headers: {
              'Content-Type': 'application/octet-stream',
            },
          )
          .timeout(const Duration(seconds: 8));

      stopwatch.stop();

      await pingFuture;

      if (response.statusCode < 200 || response.statusCode >= 400) {
        return BandwidthResult(
          mbps: 0,
          pingMs: concurrentPing,
        );
      }

      final seconds =
          stopwatch.elapsedMicroseconds / Duration.microsecondsPerSecond;

      if (seconds <= 0) {
        return BandwidthResult(
          mbps: 0,
          pingMs: concurrentPing,
        );
      }

      final megabits = (data.length * 8) / 1000000;
      final mbps = megabits / seconds;

      return BandwidthResult(
        mbps: mbps,
        pingMs: concurrentPing,
      );
    } catch (_) {
      stopwatch.stop();
      await pingFuture;

      return BandwidthResult(
        mbps: 0,
        pingMs: concurrentPing,
      );
    }
  }

  Future<void> _measureConcurrentPing({
    required void Function(double value) onResult,
  }) async {
    try {
      final result = await measurePing();
      onResult(result);
    } catch (_) {
      onResult(double.infinity);
    }
  }

  Future<NetworkDiagnosticResult> runDiagnostic() async {
    // STEP 1: Idle ping
    final idlePing = await measurePing();

    // STEP 2: Download + concurrent ping
    final download = await measureDownload();

    // STEP 3: Upload + concurrent ping
    final upload = await measureUpload();

    final health = classifyHealth(
      idlePing: idlePing,
      downloadMbps: download.mbps,
      downloadPing: download.pingMs,
      uploadMbps: upload.mbps,
      uploadPing: upload.pingMs,
    );

    return NetworkDiagnosticResult(
      idlePingMs: idlePing,
      downloadMbps: download.mbps,
      downloadPingMs: download.pingMs,
      uploadMbps: upload.mbps,
      uploadPingMs: upload.pingMs,
      health: health,
      timestamp: DateTime.now(),
    );
  }

  NetworkHealth classifyHealth({
    required double idlePing,
    required double downloadMbps,
    required double downloadPing,
    required double uploadMbps,
    required double uploadPing,
  }) {
    final pings = [
      idlePing,
      downloadPing,
      uploadPing,
    ];

    // Degraded: heavy packet loss or extreme latency (> 1000ms / timeout)
    final hasExtremeLatency = pings.any(
      (ping) => ping.isInfinite || ping > 1000,
    );

    if (hasExtremeLatency) {
      return NetworkHealth.degraded;
    }

    // Excellent: > 10 Mbps
    if (downloadMbps > 10) {
      return NetworkHealth.excellent;
    }

    // Fair: 2 - 10 Mbps
    if (downloadMbps >= 2) {
      return NetworkHealth.fair;
    }

    // Poor: < 2 Mbps
    return NetworkHealth.poor;
  }

  void dispose() {
    _client.close();
  }
}

class BandwidthResult {
  final double mbps;
  final double pingMs;

  const BandwidthResult({
    required this.mbps,
    required this.pingMs,
  });
}