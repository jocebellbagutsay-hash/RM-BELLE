import 'package:flutter/material.dart';

import 'screens/activity_counter_screen.dart';
import 'screens/activity_network_monitor_screen.dart';
import 'screens/activity_notes_screen.dart';
import 'screens/activity_mesh_chat_screen.dart';
import 'screens/activity_geofence_tracker_screen.dart';
import 'screens/home_dashboard.dart';
import 'screens/settings_screen.dart';
import 'screens/network_diagnostic_dashboard.dart';

/// Metadata definition for activities included in this compilation project.
class ActivityItem {
  const ActivityItem({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.route,
    required this.tags,
  });

  final String number;
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final String route;
  final List<String> tags;
}

/// Central routing configuration and compilation activities catalog.
class AppRoutes {
  static const String home = '/';
  static const String activityOne = '/activity/counter';
  static const String activityTwo = '/activity/notes';
  static const String activityThree = '/activity/network-monitor';
  static const String activityFour = '/activity/network-diagnostic';
  static const String activityFive = '/activity/mesh-chat';
  static const String activityGeofencing = '/activity/geofencing-tracker';
  static const String settings = '/settings';

  // Compatibility aliases
  static const String counterActivity = activityOne;
  static const String notesActivity = activityTwo;
  static const String networkMonitorActivity = activityThree;

  /// Compilation catalog of all activity screens in the project.
  static const List<ActivityItem> compilationActivities = [
    ActivityItem(
      number: 'Activity 1',
      title: 'Counter Activity',
      subtitle: 'Local state management with increment, decrement, and reset.',
      description:
          'An interactive counter demonstrating StatefulWidget lifecycle and isolated local state.',
      icon: Icons.exposure_plus_1,
      route: activityOne,
      tags: ['StatefulWidget', 'Local State', 'Buttons'],
    ),
    ActivityItem(
      number: 'Activity 2',
      title: 'Notes Activity',
      subtitle: 'Dynamic list management with interactive text input.',
      description:
          'A dynamic notepad showcasing TextEditingController, Form inputs, and responsive ListView.',
      icon: Icons.notes_outlined,
      route: activityTwo,
      tags: ['TextEditingController', 'ListView', 'Forms'],
    ),
    ActivityItem(
      number: 'Activity 3',
      title: 'Network Monitor',
      subtitle:
          'Real-time stream listener, resilient request queueing & graceful recovery.',
      description:
          'Monitors active connection interfaces (Wi-Fi, Cellular, Offline), queues long-running requests during handover or disconnects, and auto-retries upon reconnection.',
      icon: Icons.sensors_rounded,
      route: activityThree,
      tags: ['connectivity_plus', 'Streams', 'Queuing', 'Auto-Recovery'],
    ),
    ActivityItem(
  number: 'Activity 4',
  title: 'Network Diagnostic Dashboard',
  subtitle:
      'Dynamic performance throttling using real-time network diagnostics.',
  description:
      'Measures idle ping, download bandwidth, upload bandwidth, and concurrent latency to classify network health and adapt multimedia quality.',
  icon: Icons.speed,
  route: activityFour,
  tags: [
    'Network Diagnostics',
    'Provider',
    'Bandwidth',
    'Latency',
  ],
),
    ActivityItem(
      number: 'Activity 5',
      title: 'Local Mesh Chat',
      subtitle: 'Peer-to-peer localized messaging without internet.',
      description:
          'A localized Flutter messaging client that automatically discovers nearby devices and routes text payloads using nearby_connections.',
      icon: Icons.chat_bubble_outline,
      route: activityFive,
      tags: ['Nearby Connections', 'P2P', 'Messaging', 'Offline'],
    ),
    ActivityItem(
      number: 'Activity 5 (Geofencing)',
      title: 'Custom Map & Geofencing Tracker',
      subtitle: 'Custom hidden markers & real-time geofence tracking in Lianga.',
      description:
          'Interactive custom map featuring 6 authentic personal locations in Lianga, Surigao del Sur not visible on Google Maps. Includes dynamic geofence boundaries, proximity alerts, transition audit logs, and patrol simulation.',
      icon: Icons.map_rounded,
      route: activityGeofencing,
      tags: ['flutter_map', 'Geofencing', 'Lianga', 'GPS', 'Audit Log'],
    ),
  ];

  /// Standard route builder map.
  static Map<String, WidgetBuilder> get routes => {
        home: (_) => const HomeDashboard(),
        activityOne: (_) => const ActivityCounterScreen(),
        activityTwo: (_) => const ActivityNotesScreen(),
        activityThree: (_) => const ActivityNetworkMonitorScreen(),
        activityFour: (_) => const NetworkDiagnosticDashboard(),
        activityFive: (_) => const ActivityMeshChatScreen(),
        activityGeofencing: (_) => const ActivityGeofenceTrackerScreen(),
        settings: (_) => const SettingsScreen(),
      };

  /// Dynamic route generator with fallback 404 handler.
  static Route<dynamic> onGenerateRoute(RouteSettings routeSettings) {
    final name = routeSettings.name;

    // Handle null, empty, root, and browser hash URL changes smoothly
    if (name == null ||
        name.isEmpty ||
        name == '/' ||
        name == '/#' ||
        name == '/#/' ||
        name == home) {
      return MaterialPageRoute(
        builder: (_) => const HomeDashboard(),
        settings: routeSettings,
      );
    }

    final cleanName = name.startsWith('/#') ? name.substring(2) : name;
    final builder = routes[cleanName] ?? routes[name];
    if (builder != null) {
      return MaterialPageRoute(
        builder: builder,
        settings: routeSettings,
      );
    }

    return MaterialPageRoute(
      builder: (ctx) => Scaffold(
        appBar: AppBar(
          title: const Text('Route Not Found'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back to Dashboard',
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              ctx,
              AppRoutes.home,
              (route) => false,
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('No route defined for "${routeSettings.name}"'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.home),
                label: const Text('Back to Home Dashboard'),
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  ctx,
                  AppRoutes.home,
                  (route) => false,
                ),
              ),
            ],
          ),
        ),
      ),
      settings: routeSettings,
    );
  }
}
