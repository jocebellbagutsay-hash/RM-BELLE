import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/app_settings.dart';
import 'providers/network_monitor_provider.dart';
import 'providers/network_diagnostic_provider.dart';
import 'providers/geofence_tracker_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppSettings(),
        ),
        ChangeNotifierProvider(
          create: (_) => NetworkMonitorProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => NetworkDiagnosticProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => GeofenceTrackerProvider(),
        ),
      ],
      child: const PortfolioApp(),
    ),
  );
}