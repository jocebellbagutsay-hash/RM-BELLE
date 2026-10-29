import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_portfolio/app.dart';
import 'package:flutter_portfolio/models/network_request_item.dart';
import 'package:flutter_portfolio/providers/app_settings.dart';
import 'package:flutter_portfolio/providers/network_monitor_provider.dart';
import 'package:flutter_portfolio/services/network_monitor_service.dart';

Widget _buildTestApp({NetworkMonitorProvider? monitor}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AppSettings()),
      if (monitor != null)
        ChangeNotifierProvider.value(value: monitor)
      else
        ChangeNotifierProvider(create: (_) => NetworkMonitorProvider()),
    ],
    child: const PortfolioApp(),
  );
}

void main() {
  group('NetworkMonitorService unit tests', () {
    test('mapConnectivityResults maps interfaces correctly', () {
      expect(
        NetworkMonitorService.mapConnectivityResults([ConnectivityResult.wifi]),
        equals(NetworkInterfaceType.wifi),
      );
      expect(
        NetworkMonitorService.mapConnectivityResults([ConnectivityResult.mobile]),
        equals(NetworkInterfaceType.cellular),
      );
      expect(
        NetworkMonitorService.mapConnectivityResults([ConnectivityResult.none]),
        equals(NetworkInterfaceType.offline),
      );
      expect(
        NetworkMonitorService.mapConnectivityResults([]),
        equals(NetworkInterfaceType.offline),
      );
      expect(
        NetworkMonitorService.mapConnectivityResults([ConnectivityResult.ethernet]),
        equals(NetworkInterfaceType.other),
      );
      // Prioritization when multiple are present
      expect(
        NetworkMonitorService.mapConnectivityResults([
          ConnectivityResult.none,
          ConnectivityResult.wifi,
        ]),
        equals(NetworkInterfaceType.wifi),
      );
    });

    test('simulation stream emits changes', () async {
      final service = NetworkMonitorService(
        isSimulationMode: true,
        simulatedType: NetworkInterfaceType.wifi,
      );
      final emitted = <NetworkInterfaceType>[];

      final sub = service.onInterfaceChanged.listen((event) {
        emitted.add(event);
      });

      service.simulateNetworkInterface(NetworkInterfaceType.offline);
      service.simulateNetworkInterface(NetworkInterfaceType.cellular);
      service.simulateNetworkInterface(NetworkInterfaceType.wifi);

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(emitted, [
        NetworkInterfaceType.offline,
        NetworkInterfaceType.cellular,
        NetworkInterfaceType.wifi,
      ]);

      await sub.cancel();
      service.dispose();
    });
  });

  group('NetworkMonitorProvider unit tests', () {
    test('queues request when offline and auto-recovers when online', () async {
      final service = NetworkMonitorService(
        isSimulationMode: true,
        simulatedType: NetworkInterfaceType.offline,
      );
      final provider = NetworkMonitorProvider(
        service: service,
        initialInterface: NetworkInterfaceType.offline,
      );

      expect(provider.isOnline, isFalse);

      // Enqueue while offline
      await provider.enqueueRequest(
        title: 'Offline Test Sync',
        totalBytes: 1000,
        chunks: 2,
      );

      expect(provider.requests.length, 1);
      expect(provider.requests.first.status, RequestStatus.queued);
      expect(provider.queuedCount, 1);

      // Re-establish connection to Wi-Fi
      provider.simulateInterface(NetworkInterfaceType.wifi);
      expect(provider.isOnline, isTrue);

      // Wait for execution to process queue
      await Future<void>.delayed(const Duration(milliseconds: 2500));

      expect(provider.requests.first.status, RequestStatus.completed);
      expect(provider.completedCount, 1);
      expect(provider.queuedCount, 0);

      provider.dispose();
    });

    test('catches connection drop mid-flight, queues request without crashing',
        () async {
      final service = NetworkMonitorService(
        isSimulationMode: true,
        simulatedType: NetworkInterfaceType.wifi,
      );
      final provider = NetworkMonitorProvider(
        service: service,
        initialInterface: NetworkInterfaceType.wifi,
      );

      // Start a request with multiple chunks
      unawaited(
        provider.enqueueRequest(
          title: 'Handover Test Request',
          totalBytes: 2000000,
          chunks: 10,
        ),
      );

      // Give it time to start running
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(provider.runningCount, 1);

      // Drop connection during handover / IP migration
      provider.simulateInterface(NetworkInterfaceType.offline);
      await Future<void>.delayed(const Duration(milliseconds: 350));

      // The running request should have caught the disconnect error and transitioned to queued
      expect(provider.runningCount, 0);
      expect(provider.queuedCount, 1);
      final req = provider.requests.first;
      expect(req.status, RequestStatus.queued);
      expect(req.retryCount, greaterThanOrEqualTo(1));
      expect(req.lastError, contains('handover'));

      // Graceful recovery: re-establish connection via Cellular
      provider.simulateInterface(NetworkInterfaceType.cellular);
      expect(provider.isOnline, isTrue);

      // Wait for auto-recovery to finish all chunks
      await Future<void>.delayed(const Duration(milliseconds: 3000));
      expect(provider.requests.first.status, RequestStatus.completed);

      provider.dispose();
    });
  });

  group('ActivityNetworkMonitorScreen widget tests', () {
    testWidgets('navigates from home dashboard to Activity 3 Network Monitor',
        (tester) async {
      final service = NetworkMonitorService(
        isSimulationMode: true,
        simulatedType: NetworkInterfaceType.wifi,
      );
      final monitor = NetworkMonitorProvider(
        service: service,
        initialInterface: NetworkInterfaceType.wifi,
      );

      await tester.pumpWidget(_buildTestApp(monitor: monitor));
      await tester.pumpAndSettle();

      // Scroll to Activity 3 card on dashboard and tap it
      await tester.ensureVisible(find.text('Network Monitor'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Network Monitor'));
      await tester.pumpAndSettle();

      expect(find.text('Activity 3: Network Monitor'), findsOneWidget);
      expect(find.text('Activities Compilation • Activity 3'), findsOneWidget);
      expect(find.text('Connected to Wi-Fi'), findsOneWidget);
      expect(find.text('Request Queuing System'), findsOneWidget);

      monitor.dispose();
    });

    testWidgets(
        'real-time UI dynamically updates when interface switches to Cellular & Offline',
        (tester) async {
      final service = NetworkMonitorService(
        isSimulationMode: true,
        simulatedType: NetworkInterfaceType.wifi,
      );
      final monitor = NetworkMonitorProvider(
        service: service,
        initialInterface: NetworkInterfaceType.wifi,
      );

      await tester.pumpWidget(_buildTestApp(monitor: monitor));
      await tester.pumpAndSettle();

      // Navigate to Activity 3
      await tester.ensureVisible(find.text('Network Monitor'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Network Monitor'));
      await tester.pumpAndSettle();

      expect(find.text('Connected to Wi-Fi'), findsOneWidget);

      // Tap "Simulate Cellular" chip
      await tester.ensureVisible(find.text('Simulate Cellular'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simulate Cellular'));
      await tester.pumpAndSettle();

      expect(find.text('Connected to Cellular (Mobile Data)'), findsOneWidget);

      // Tap "Simulate Disconnect (Offline)" chip
      await tester.ensureVisible(find.text('Simulate Disconnect (Offline)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simulate Disconnect (Offline)'));
      await tester.pumpAndSettle();

      expect(find.text('Device is Offline'), findsOneWidget);

      monitor.dispose();
    });

    testWidgets('tapping fetch buttons adds requests to queuing system',
        (tester) async {
      final service = NetworkMonitorService(
        isSimulationMode: true,
        simulatedType: NetworkInterfaceType.offline,
      );
      final monitor = NetworkMonitorProvider(
        service: service,
        initialInterface: NetworkInterfaceType.offline,
      );

      await tester.pumpWidget(_buildTestApp(monitor: monitor));
      await tester.pumpAndSettle();

      // Navigate to Activity 3
      await tester.ensureVisible(find.text('Network Monitor'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Network Monitor'));
      await tester.pumpAndSettle();

      // Tap "Fetch Large Dataset (5MB)"
      await tester.ensureVisible(find.text('Fetch Large Dataset (5MB)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fetch Large Dataset (5MB)'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Data Package #1'), findsWidgets);
      expect(find.text('Queued (Awaiting Network)'), findsOneWidget);

      // Tap "Enqueue Batch (3 Requests)"
      await tester.ensureVisible(find.text('Enqueue Batch (3 Requests)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enqueue Batch (3 Requests)'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Telemetry Batch'), findsWidgets);
      expect(monitor.requests.length, 4);

      monitor.dispose();
    });
  });
}
