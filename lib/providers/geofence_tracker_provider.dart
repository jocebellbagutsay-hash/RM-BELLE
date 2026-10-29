import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/geofence_location.dart';

enum TrackingMode {
  manual,
  simulation,
  liveGps,
}

class GeofenceTrackerProvider extends ChangeNotifier {
  GeofenceTrackerProvider() {
    _locations = GeofenceLocation.getLiangaLocations();
    // Default initial location: near Balay ni Lola in Lianga Poblacion
    _currentPosition = const LatLng(8.6335, 126.0948);
    _breadcrumbs.add(_currentPosition!);
    _evaluateGeofences(_currentPosition!);
  }

  static const Distance _distanceCalculator = Distance();

  late List<GeofenceLocation> _locations;
  LatLng? _currentPosition;
  TrackingMode _trackingMode = TrackingMode.manual;
  final Set<String> _activeGeofenceIds = {};
  final List<GeofenceEvent> _eventLogs = [];
  final List<LatLng> _breadcrumbs = [];
  GeofenceEvent? _latestEvent;

  // Simulation state
  Timer? _simulationTimer;
  int _simulationWaypointIndex = 0;
  List<LatLng> _simulationRoute = [];
  bool _isSimulationPaused = false;

  // Live GPS stream
  StreamSubscription<Position>? _gpsSubscription;
  String? _gpsErrorMessage;

  // Getters
  List<GeofenceLocation> get locations => List.unmodifiable(_locations);
  LatLng? get currentPosition => _currentPosition;
  TrackingMode get trackingMode => _trackingMode;
  Set<String> get activeGeofenceIds => Set.unmodifiable(_activeGeofenceIds);
  List<GeofenceEvent> get eventLogs => List.unmodifiable(_eventLogs.reversed);
  List<LatLng> get breadcrumbs => List.unmodifiable(_breadcrumbs);
  GeofenceEvent? get latestEvent => _latestEvent;
  bool get isSimulating => _trackingMode == TrackingMode.simulation && !_isSimulationPaused;
  bool get isGpsActive => _trackingMode == TrackingMode.liveGps;
  String? get gpsErrorMessage => _gpsErrorMessage;

  /// Check whether a specific location ID has an active geofence
  bool isInsideGeofence(String locationId) => _activeGeofenceIds.contains(locationId);

  /// Calculate distance from current position to a location in meters
  double? getDistanceTo(GeofenceLocation location) {
    if (_currentPosition == null) return null;
    return _distanceCalculator.as(
      LengthUnit.Meter,
      _currentPosition!,
      location.point,
    );
  }

  /// Update the current user position manually (e.g. by tapping on the map)
  void setManualPosition(LatLng position) {
    if (_trackingMode == TrackingMode.liveGps) {
      stopLiveGps();
    }
    if (_trackingMode == TrackingMode.simulation) {
      stopSimulation();
    }

    _trackingMode = TrackingMode.manual;
    _gpsErrorMessage = null;
    _applyNewPosition(position);
  }

  /// Teleport directly to a designated secret spot
  void teleportToLocation(GeofenceLocation location) {
    setManualPosition(location.point);
  }

  /// Evaluate geofences for a newly arrived position
  void _applyNewPosition(LatLng position) {
    _currentPosition = position;
    _breadcrumbs.add(position);
    if (_breadcrumbs.length > 300) {
      _breadcrumbs.removeAt(0);
    }

    _evaluateGeofences(position);
    notifyListeners();
  }

  /// Core Geofencing Algorithm
  void _evaluateGeofences(LatLng userPos) {
    final now = DateTime.now();

    for (final loc in _locations) {
      final double distance = _distanceCalculator.as(
        LengthUnit.Meter,
        userPos,
        loc.point,
      );

      final bool wasInside = _activeGeofenceIds.contains(loc.id);
      final bool isNowInside = distance <= loc.radiusMeters;

      if (!wasInside && isNowInside) {
        // ENTER transition
        _activeGeofenceIds.add(loc.id);
        final event = GeofenceEvent(
          id: 'event_${now.millisecondsSinceEpoch}_${loc.id}',
          locationId: loc.id,
          locationName: loc.name,
          type: GeofenceEventType.enter,
          timestamp: now,
          distanceMeters: distance,
          userPoint: userPos,
          notes: 'Entered perimeter (Fence radius: ${loc.radiusMeters.toStringAsFixed(0)}m)',
        );
        _eventLogs.add(event);
        _latestEvent = event;
      } else if (wasInside && !isNowInside) {
        // EXIT transition
        _activeGeofenceIds.remove(loc.id);
        final event = GeofenceEvent(
          id: 'event_${now.millisecondsSinceEpoch}_${loc.id}',
          locationId: loc.id,
          locationName: loc.name,
          type: GeofenceEventType.exit,
          timestamp: now,
          distanceMeters: distance,
          userPoint: userPos,
          notes: 'Exited perimeter (Distance: ${distance.toStringAsFixed(1)}m)',
        );
        _eventLogs.add(event);
        _latestEvent = event;
      }
    }
  }

  // -------------------------------------------------------------
  // SIMULATION MODE: Automated tour through all secret spots
  // -------------------------------------------------------------

  /// Build smooth interpolated route between all spots
  void _buildSimulationRoute() {
    final List<LatLng> waypoints = [
      ..._locations.map((e) => e.point),
      _locations.first.point, // loop back
    ];

    _simulationRoute = [];
    const int stepsPerSegment = 12;

    for (int i = 0; i < waypoints.length - 1; i++) {
      final start = waypoints[i];
      final end = waypoints[i + 1];

      for (int step = 0; step < stepsPerSegment; step++) {
        final double t = step / stepsPerSegment;
        final double lat = start.latitude + (end.latitude - start.latitude) * t;
        final double lng = start.longitude + (end.longitude - start.longitude) * t;
        _simulationRoute.add(LatLng(lat, lng));
      }
    }
  }

  void startSimulation() {
    if (_trackingMode == TrackingMode.liveGps) {
      stopLiveGps();
    }

    _trackingMode = TrackingMode.simulation;
    _isSimulationPaused = false;
    _gpsErrorMessage = null;

    if (_simulationRoute.isEmpty) {
      _buildSimulationRoute();
      _simulationWaypointIndex = 0;
    }

    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 1400), (timer) {
      if (_simulationRoute.isEmpty) return;

      final nextPoint = _simulationRoute[_simulationWaypointIndex];
      _simulationWaypointIndex = (_simulationWaypointIndex + 1) % _simulationRoute.length;

      _applyNewPosition(nextPoint);
    });

    notifyListeners();
  }

  void pauseSimulation() {
    _simulationTimer?.cancel();
    _isSimulationPaused = true;
    notifyListeners();
  }

  void stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _isSimulationPaused = false;
    if (_trackingMode == TrackingMode.simulation) {
      _trackingMode = TrackingMode.manual;
    }
    notifyListeners();
  }

  // -------------------------------------------------------------
  // LIVE GPS MODE: Device location stream
  // -------------------------------------------------------------

  Future<void> startLiveGps() async {
    stopSimulation();
    _gpsErrorMessage = null;

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _gpsErrorMessage = 'Location services are disabled on your device.';
        notifyListeners();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _gpsErrorMessage = 'Location permissions were denied.';
          notifyListeners();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _gpsErrorMessage = 'Location permissions are permanently denied.';
        notifyListeners();
        return;
      }

      _trackingMode = TrackingMode.liveGps;
      notifyListeners();

      // Get initial position
      final initialPos = await Geolocator.getCurrentPosition();
      _applyNewPosition(LatLng(initialPos.latitude, initialPos.longitude));

      // Subscribe to real-time changes
      _gpsSubscription?.cancel();
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
      );

      _gpsSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
        (Position pos) {
          _applyNewPosition(LatLng(pos.latitude, pos.longitude));
        },
        onError: (e) {
          _gpsErrorMessage = 'GPS Error: $e';
          notifyListeners();
        },
      );
    } catch (e) {
      _gpsErrorMessage = 'Unable to initialize GPS: $e';
      _trackingMode = TrackingMode.manual;
      notifyListeners();
    }
  }

  void stopLiveGps() {
    _gpsSubscription?.cancel();
    _gpsSubscription = null;
    if (_trackingMode == TrackingMode.liveGps) {
      _trackingMode = TrackingMode.manual;
    }
    notifyListeners();
  }

  // -------------------------------------------------------------
  // CUSTOM LOCATION MANAGEMENT
  // -------------------------------------------------------------

  void addCustomSpot({
    required String name,
    required String localTag,
    required String category,
    required String description,
    required String hiddenDetails,
    required LatLng point,
    double radiusMeters = 50.0,
    IconData icon = Icons.star_rounded,
    Color accentColor = const Color(0xFF0EA5E9),
  }) {
    final newSpot = GeofenceLocation(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      localTag: localTag,
      category: category,
      description: description,
      hiddenDetails: hiddenDetails,
      point: point,
      radiusMeters: radiusMeters,
      icon: icon,
      accentColor: accentColor,
      isCustom: true,
    );

    _locations.add(newSpot);
    if (_trackingMode == TrackingMode.simulation) {
      _buildSimulationRoute();
    }
    if (_currentPosition != null) {
      _evaluateGeofences(_currentPosition!);
    }
    notifyListeners();
  }

  void updateRadius(String locationId, double newRadius) {
    final index = _locations.indexWhere((loc) => loc.id == locationId);
    if (index != -1) {
      _locations[index].radiusMeters = newRadius;
      if (_currentPosition != null) {
        _evaluateGeofences(_currentPosition!);
      }
      notifyListeners();
    }
  }

  void clearLogs() {
    _eventLogs.clear();
    _latestEvent = null;
    notifyListeners();
  }

  void clearBreadcrumbs() {
    _breadcrumbs.clear();
    if (_currentPosition != null) {
      _breadcrumbs.add(_currentPosition!);
    }
    notifyListeners();
  }

  void resetToLiangaCenter() {
    setManualPosition(const LatLng(8.6335, 126.0948));
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _gpsSubscription?.cancel();
    super.dispose();
  }
}
