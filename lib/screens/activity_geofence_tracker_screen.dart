import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/geofence_location.dart';
import '../providers/geofence_tracker_provider.dart';
import '../routes.dart';

class ActivityGeofenceTrackerScreen extends StatefulWidget {
  const ActivityGeofenceTrackerScreen({super.key});

  @override
  State<ActivityGeofenceTrackerScreen> createState() =>
      _ActivityGeofenceTrackerScreenState();
}

class _ActivityGeofenceTrackerScreenState
    extends State<ActivityGeofenceTrackerScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _autoCenter = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _centerOn(LatLng point, {double zoom = 16.5}) {
    _mapController.move(point, zoom);
  }

  @override
  Widget build(BuildContext context) {
    final tracker = context.watch<GeofenceTrackerProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentPos = tracker.currentPosition ?? const LatLng(8.6335, 126.0950);

    // Auto-center map if enabled during simulation or tracking
    if (_autoCenter) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(currentPos, _mapController.camera.zoom);
      });
    }

    // Find nearest location
    GeofenceLocation? nearestLoc;
    double minDistance = double.infinity;
    for (final loc in tracker.locations) {
      final d = tracker.getDistanceTo(loc);
      if (d != null && d < minDistance) {
        minDistance = d;
        nearestLoc = loc;
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.home,
            (route) => false,
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back to Dashboard',
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRoutes.home,
                  (route) => false,
                );
              }
            },
          ),
          title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activity 5: Geofencing Tracker',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Lianga, Surigao del Sur • Custom Hidden Map',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'View Geofence Audit Log',
            icon: Badge(
              label: Text('${tracker.eventLogs.length}'),
              isLabelVisible: tracker.eventLogs.isNotEmpty,
              child: const Icon(Icons.history_rounded),
            ),
            onPressed: () => _showAuditLogSheet(context, tracker),
          ),
          IconButton(
            tooltip: 'Add Custom Secret Spot',
            icon: const Icon(Icons.add_location_alt_outlined),
            onPressed: () => _showAddSpotDialog(context, tracker, currentPos),
          ),
          IconButton(
            tooltip: 'Reset Tracker to Lianga Center',
            icon: const Icon(Icons.my_location_rounded),
            onPressed: () {
              tracker.resetToLiangaCenter();
              _centerOn(const LatLng(8.6335, 126.0948));
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // -----------------------------------------------------------
          // 1. Interactive FlutterMap
          // -----------------------------------------------------------
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(8.6335, 126.0950),
              initialZoom: 16.0,
              minZoom: 13.0,
              maxZoom: 19.0,
              onTap: (tapPos, point) {
                tracker.setManualPosition(point);
              },
              onLongPress: (tapPos, point) {
                _showAddSpotDialog(context, tracker, point);
              },
            ),
            children: [
              // OpenStreetMap Tile Layer
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.flutter_portfolio',
                maxZoom: 19,
              ),

              // Breadcrumb Trail (Tracking Polyline)
              if (tracker.breadcrumbs.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: tracker.breadcrumbs,
                      strokeWidth: 3.5,
                      color: colorScheme.primary.withValues(alpha: 0.75),
                      borderStrokeWidth: 1.0,
                      borderColor: Colors.white,
                    ),
                  ],
                ),

              // Geofence Circular Zones
              CircleLayer(
                circles: tracker.locations.map((loc) {
                  final isInside = tracker.isInsideGeofence(loc.id);
                  return CircleMarker(
                    point: loc.point,
                    radius: loc.radiusMeters,
                    useRadiusInMeter: true,
                    color: isInside
                        ? loc.accentColor.withValues(alpha: 0.38)
                        : loc.accentColor.withValues(alpha: 0.18),
                    borderColor: isInside ? Colors.greenAccent : loc.accentColor,
                    borderStrokeWidth: isInside ? 3.5 : 1.5,
                  );
                }).toList(),
              ),

              // Markers Layer: Custom Hidden Spots + User Location Pin
              MarkerLayer(
                markers: [
                  // Hidden custom spots pins
                  ...tracker.locations.map((loc) {
                    final isInside = tracker.isInsideGeofence(loc.id);
                    return Marker(
                      point: loc.point,
                      width: 100,
                      height: 80,
                      child: GestureDetector(
                        onTap: () {
                          _showLocationDetailSheet(context, loc, tracker);
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Mini Name Pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isInside
                                    ? Colors.green.shade800
                                    : Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isInside
                                      ? Colors.greenAccent
                                      : loc.accentColor,
                                  width: 1.2,
                                ),
                              ),
                              child: Text(
                                loc.name.split('(').first.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: isInside
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            // Marker Icon Pin
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isInside
                                    ? Colors.green.shade600
                                    : loc.accentColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2.0,
                                ),
                              ),
                              child: Icon(
                                loc.icon,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  // User Tracker Pin
                  Marker(
                    point: currentPos,
                    width: 70,
                    height: 70,
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Pulsing radar ring
                            Container(
                              width: 50 * _pulseAnimation.value,
                              height: 50 * _pulseAnimation.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colorScheme.primary.withValues(
                                    alpha: (0.25 / _pulseAnimation.value).clamp(0.0, 1.0)),
                                border: Border.all(
                                  color: colorScheme.primary.withValues(alpha: 0.5),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            // Center avatar pin
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.person_pin_circle_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),

          // -----------------------------------------------------------
          // 2. Top HUD: Geofence Active Alert & Status Pill
          // -----------------------------------------------------------
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: SafeArea(
              child: Column(
                children: [
                  _buildGeofenceHudBanner(context, tracker, nearestLoc, minDistance),
                  if (tracker.gpsErrorMessage != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade900.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tracker.gpsErrorMessage!,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // -----------------------------------------------------------
          // 3. Floating Quick Action Deck
          // -----------------------------------------------------------
          Positioned(
            right: 12,
            bottom: 175,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Toggle Auto-Center
                FloatingActionButton.small(
                  heroTag: 'fab_autocenter',
                  tooltip: _autoCenter
                      ? 'Disable Auto-Follow'
                      : 'Enable Auto-Follow Tracker',
                  backgroundColor: _autoCenter
                      ? colorScheme.primary
                      : theme.cardColor,
                  foregroundColor: _autoCenter
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                  onPressed: () {
                    setState(() {
                      _autoCenter = !_autoCenter;
                    });
                    if (_autoCenter) {
                      _centerOn(currentPos);
                    }
                  },
                  child: Icon(_autoCenter
                      ? Icons.lock_rounded
                      : Icons.lock_open_rounded),
                ),
                const SizedBox(height: 8),

                // Center Map on Tracker
                FloatingActionButton.small(
                  heroTag: 'fab_center',
                  tooltip: 'Center on Current Tracker',
                  backgroundColor: theme.cardColor,
                  foregroundColor: colorScheme.primary,
                  onPressed: () => _centerOn(currentPos),
                  child: const Icon(Icons.gps_fixed_rounded),
                ),
                const SizedBox(height: 8),

                // Clear Breadcrumb Trail
                FloatingActionButton.small(
                  heroTag: 'fab_clear_trail',
                  tooltip: 'Clear Path Trail',
                  backgroundColor: theme.cardColor,
                  foregroundColor: colorScheme.onSurface,
                  onPressed: () => tracker.clearBreadcrumbs(),
                  child: const Icon(Icons.layers_clear_outlined),
                ),
              ],
            ),
          ),

          // -----------------------------------------------------------
          // 4. Bottom Spots Carousel & Simulation Deck
          // -----------------------------------------------------------
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardColor.withValues(alpha: 0.96),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mode and Control Row
                    Row(
                      children: [
                        // Simulation Tour Button
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: tracker.isSimulating
                                  ? Colors.amber.shade700
                                  : colorScheme.primary,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                            ),
                            icon: Icon(
                              tracker.isSimulating
                                  ? Icons.pause_circle_rounded
                                  : Icons.play_circle_fill_rounded,
                            ),
                            label: Text(
                              tracker.isSimulating
                                  ? 'Pause Tour'
                                  : 'Start Patrol Walk',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            onPressed: () {
                              if (tracker.isSimulating) {
                                tracker.pauseSimulation();
                              } else {
                                tracker.startSimulation();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Live GPS Toggle Button
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: tracker.isGpsActive
                                ? colorScheme.primaryContainer
                                : null,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          icon: Icon(
                            tracker.isGpsActive
                                ? Icons.location_on
                                : Icons.location_searching,
                            color: tracker.isGpsActive
                                ? colorScheme.primary
                                : null,
                            size: 18,
                          ),
                          label: Text(
                            tracker.isGpsActive ? 'GPS Active' : 'Live GPS',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () {
                            if (tracker.isGpsActive) {
                              tracker.stopLiveGps();
                            } else {
                              tracker.startLiveGps();
                            }
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Horizontal Spots Carousel
                    SizedBox(
                      height: 84,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: tracker.locations.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final loc = tracker.locations[index];
                          final isInside = tracker.isInsideGeofence(loc.id);
                          final dist = tracker.getDistanceTo(loc);

                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              _centerOn(loc.point);
                              _showLocationDetailSheet(context, loc, tracker);
                            },
                            child: Container(
                              width: 180,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isInside
                                    ? Colors.green.withValues(alpha: 0.12)
                                    : theme.colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isInside
                                      ? Colors.greenAccent.shade700
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: loc.accentColor,
                                        child: Icon(loc.icon,
                                            size: 14, color: Colors.white),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          loc.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isInside
                                              ? Colors.green
                                              : colorScheme.surface,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isInside
                                              ? 'INSIDE'
                                              : '${dist?.toStringAsFixed(0) ?? '--'}m away',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isInside
                                                ? Colors.white
                                                : colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        'r: ${loc.radiusMeters.toStringAsFixed(0)}m',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: colorScheme.outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // End of Stack children
        ],
      ),
    ),
  );
}

  // -------------------------------------------------------------
  // Top HUD Banner
  // -------------------------------------------------------------
  Widget _buildGeofenceHudBanner(
    BuildContext context,
    GeofenceTrackerProvider tracker,
    GeofenceLocation? nearestLoc,
    double minDistance,
  ) {
    final theme = Theme.of(context);
    final activeIds = tracker.activeGeofenceIds;

    if (activeIds.isNotEmpty) {
      final activeLocs = tracker.locations
          .where((loc) => activeIds.contains(loc.id))
          .toList();

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.green.shade800.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.green.shade900.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.greenAccent, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.near_me_rounded,
                  color: Colors.green.shade800, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'INSIDE GEOFENCE (${activeLocs.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    activeLocs.map((e) => e.name).join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
              ),
              onPressed: () {
                _centerOn(activeLocs.first.point);
                _showLocationDetailSheet(context, activeLocs.first, tracker);
              },
              child: const Text('View', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    // Outside all geofences
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.radar_rounded,
              color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'OUTSIDE GEOFENCES • TAP MAP TO WALK',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text(
                  nearestLoc != null
                      ? 'Nearest: ${nearestLoc.name} (${minDistance.toStringAsFixed(0)}m)'
                      : 'Locating nearby spots...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (nearestLoc != null)
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
              ),
              onPressed: () {
                tracker.teleportToLocation(nearestLoc);
                _centerOn(nearestLoc.point);
              },
              child: const Text('Teleport', style: TextStyle(fontSize: 11)),
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Location Detail Bottom Sheet
  // -------------------------------------------------------------
  void _showLocationDetailSheet(
    BuildContext context,
    GeofenceLocation loc,
    GeofenceTrackerProvider tracker,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(sheetContext);
            final isInside = tracker.isInsideGeofence(loc.id);
            final dist = tracker.getDistanceTo(loc);

            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header with category badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: loc.accentColor,
                        child: Icon(loc.icon, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loc.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              loc.localTag,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isInside
                              ? Colors.green.shade600
                              : theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isInside
                              ? 'INSIDE ZONE'
                              : '${dist?.toStringAsFixed(0) ?? '--'}m',
                          style: TextStyle(
                            color: isInside
                                ? Colors.white
                                : theme.colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Why not on Google Maps badge
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade900.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.amber.shade700.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.visibility_off_outlined,
                            size: 18, color: Colors.amber.shade800),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Not Visible on Google Maps',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                loc.hiddenDetails,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Description
                  Text(
                    loc.description,
                    style: theme.textTheme.bodyMedium,
                  ),

                  const SizedBox(height: 16),

                  // Geofence Radius Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Geofence Radius:',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${loc.radiusMeters.toStringAsFixed(0)} meters',
                        style: TextStyle(
                          color: loc.accentColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: loc.radiusMeters,
                    min: 20.0,
                    max: 120.0,
                    divisions: 20,
                    label: '${loc.radiusMeters.toStringAsFixed(0)}m',
                    activeColor: loc.accentColor,
                    onChanged: (val) {
                      setSheetState(() {
                        tracker.updateRadius(loc.id, val);
                      });
                    },
                  ),

                  const SizedBox(height: 12),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.navigation_outlined),
                          label: const Text('Center Map'),
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _centerOn(loc.point);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: loc.accentColor,
                          ),
                          icon: const Icon(Icons.directions_walk_rounded),
                          label: const Text('Teleport Here'),
                          onPressed: () {
                            tracker.teleportToLocation(loc);
                            Navigator.pop(sheetContext);
                            _centerOn(loc.point);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------
  // Geofence Audit Log Sheet
  // -------------------------------------------------------------
  void _showAuditLogSheet(
    BuildContext context,
    GeofenceTrackerProvider tracker,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final logs = tracker.eventLogs;

        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Geofence Audit Log',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${logs.length} transition events recorded',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      if (logs.isNotEmpty)
                        TextButton.icon(
                          icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                          label: const Text('Clear Log'),
                          onPressed: () {
                            tracker.clearLogs();
                            Navigator.pop(ctx);
                          },
                        ),
                    ],
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: logs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.playlist_add_check_rounded,
                                    size: 48,
                                    color: theme.colorScheme.outlineVariant),
                                const SizedBox(height: 10),
                                Text(
                                  'No geofence events logged yet',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tap the map or start the patrol walk to trigger fences.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: logs.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final event = logs[index];
                              final isEnter = event.isEnter;

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: isEnter
                                      ? Colors.green.shade100
                                      : Colors.amber.shade100,
                                  child: Icon(
                                    isEnter
                                        ? Icons.login_rounded
                                        : Icons.logout_rounded,
                                    color: isEnter
                                        ? Colors.green.shade800
                                        : Colors.amber.shade900,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  '${isEnter ? 'ENTERED' : 'EXITED'}: ${event.locationName}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                subtitle: Text(
                                  '${event.notes} • ${_formatTime(event.timestamp)}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: Text(
                                  '${event.distanceMeters.toStringAsFixed(1)}m',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: isEnter
                                        ? Colors.green.shade700
                                        : Colors.amber.shade800,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------
  // Add Custom Secret Spot Dialog
  // -------------------------------------------------------------
  void _showAddSpotDialog(
    BuildContext context,
    GeofenceTrackerProvider tracker,
    LatLng initialPoint,
  ) {
    final nameController = TextEditingController();
    final tagController = TextEditingController(text: 'Lianga, Surigao del Sur');
    final descController = TextEditingController();
    final secretController = TextEditingController();
    double radius = 45.0;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.add_location_alt_rounded),
                  SizedBox(width: 8),
                  Text('Add Secret Location', style: TextStyle(fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Location Name',
                        hintText: 'e.g. My Secret Rooftop',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: tagController,
                      decoration: const InputDecoration(
                        labelText: 'Barangay / Purok Area',
                        hintText: 'e.g. Purok 1, Poblacion, Lianga',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Describe this personal spot...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: secretController,
                      decoration: const InputDecoration(
                        labelText: 'Why not on Google Maps?',
                        hintText: 'e.g. Private family yard, unmapped alley...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Fence Radius:'),
                        Text('${radius.toStringAsFixed(0)}m',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Slider(
                      value: radius,
                      min: 20.0,
                      max: 100.0,
                      divisions: 16,
                      onChanged: (val) {
                        setDialogState(() {
                          radius = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (nameController.text.trim().isEmpty) return;
                    tracker.addCustomSpot(
                      name: nameController.text.trim(),
                      localTag: tagController.text.trim(),
                      category: 'Custom Spot',
                      description: descController.text.trim().isEmpty
                          ? 'Custom user-created secret spot.'
                          : descController.text.trim(),
                      hiddenDetails: secretController.text.trim().isEmpty
                          ? 'Personal unindexed location added by user.'
                          : secretController.text.trim(),
                      point: initialPoint,
                      radiusMeters: radius,
                      icon: Icons.bookmark_added_rounded,
                      accentColor: const Color(0xFF0284C7),
                    );
                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added "${nameController.text.trim()}"!'),
                      ),
                    );
                  },
                  child: const Text('Save Spot'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final sec = dt.second.toString().padLeft(2, '0');
    return '$hour:$min:$sec';
  }
}
