import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_portfolio/models/network_diagnostic_result.dart';
import 'package:flutter_portfolio/services/network_diagnostic_service.dart';
import 'package:flutter_portfolio/providers/network_diagnostic_provider.dart';
import 'package:flutter_portfolio/screens/network_diagnostic_dashboard.dart';

void main() {
  group('NetworkDiagnosticService Threshold Tests', () {
    final service = NetworkDiagnosticService();

    test('classifies download > 10 Mbps as excellent', () {
      final health = service.classifyHealth(
        idlePing: 25,
        downloadMbps: 25.5,
        downloadPing: 30,
        uploadMbps: 12.0,
        uploadPing: 35,
      );
      expect(health, NetworkHealth.excellent);
    });

    test('classifies download 2 - 10 Mbps as fair', () {
      final health = service.classifyHealth(
        idlePing: 45,
        downloadMbps: 6.2,
        downloadPing: 55,
        uploadMbps: 3.0,
        uploadPing: 60,
      );
      expect(health, NetworkHealth.fair);
    });

    test('classifies download < 2 Mbps as poor', () {
      final health = service.classifyHealth(
        idlePing: 80,
        downloadMbps: 1.2,
        downloadPing: 110,
        uploadMbps: 0.5,
        uploadPing: 120,
      );
      expect(health, NetworkHealth.poor);
    });

    test('classifies extreme latency or packet loss (>1000ms/infinity) as degraded', () {
      final healthInfinity = service.classifyHealth(
        idlePing: double.infinity,
        downloadMbps: 15.0,
        downloadPing: 50,
        uploadMbps: 5.0,
        uploadPing: 60,
      );
      expect(healthInfinity, NetworkHealth.degraded);

      final healthHighPing = service.classifyHealth(
        idlePing: 30,
        downloadMbps: 15.0,
        downloadPing: 1200,
        uploadMbps: 5.0,
        uploadPing: 60,
      );
      expect(healthHighPing, NetworkHealth.degraded);
    });
  });

  group('NetworkDiagnosticProvider & UI Dynamic Throttling Tests', () {
    testWidgets('adapts UI dynamically across all 4 operational tiers',
        (tester) async {
      final provider = NetworkDiagnosticProvider();

      // Render the dashboard with provider
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<NetworkDiagnosticProvider>.value(
            value: provider,
            child: const NetworkDiagnosticDashboard(),
          ),
        ),
      );
      await tester.pump();

      // 1. Simulate Tier 1 (Excellent): 1080p Ultra HD mode
      provider.setHealthForTesting(NetworkHealth.excellent);
      await tester.pumpAndSettle();

      expect(find.text('Tier 1: Ultra High-Definition Mode'), findsOneWidget);
      expect(find.text('1080p Ultra HD Media (4.8 MB)'), findsOneWidget);

      // 2. Simulate Tier 2 (Fair): 720p Standard mode
      provider.setHealthForTesting(NetworkHealth.fair);
      await tester.pumpAndSettle();

      expect(find.text('Tier 2: Standard Definition Mode'), findsOneWidget);
      expect(find.text('720p Standard Balanced Stream (1.2 MB)'), findsOneWidget);

      // 3. Simulate Tier 3 (Poor): 240p Micro-Thumbnail mode
      provider.setHealthForTesting(NetworkHealth.poor);
      await tester.pumpAndSettle();

      expect(find.text('Tier 3: Low-Bandwidth Micro-Mode'), findsOneWidget);
      expect(find.text('High-Resolution Stream Suppressed'), findsOneWidget);

      // 4. Simulate Tier 4 (Degraded): Zero-Data Placeholder mode
      provider.setHealthForTesting(NetworkHealth.degraded);
      await tester.pumpAndSettle();

      expect(find.text('Tier 4: Zero-Data Placeholder Mode'), findsOneWidget);
      expect(find.text('Zero-Data Vector Placeholder'), findsOneWidget);
    });

    test('verifies startMonitoring and stopMonitoring lifecycle and state', () {
      final provider = NetworkDiagnosticProvider();
      expect(provider.isMonitoring, false);
      expect(provider.countdown, 0);

      // Start automatic monitoring
      provider.startMonitoring(intervalSeconds: 10);
      expect(provider.isMonitoring, true);
      expect(provider.countdown, 10);

      // Stop automatic monitoring
      provider.stopMonitoring();
      expect(provider.isMonitoring, false);
      expect(provider.countdown, 0);
    });
  });
}
