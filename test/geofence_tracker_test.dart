import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_portfolio/models/geofence_location.dart';
import 'package:flutter_portfolio/providers/geofence_tracker_provider.dart';

void main() {
  group('GeofenceLocation Models', () {
    test('Lianga default locations contain at least 5 custom undiscovered spots', () {
      final spots = GeofenceLocation.getLiangaLocations();
      expect(spots.length, greaterThanOrEqualTo(5));

      for (final spot in spots) {
        expect(spot.name.isNotEmpty, isTrue);
        expect(spot.localTag.contains('Lianga'), isTrue);
        expect(spot.hiddenDetails.isNotEmpty, isTrue);
        expect(spot.radiusMeters, greaterThan(0));
        expect(spot.latitude, inInclusiveRange(8.60, 8.70));
        expect(spot.longitude, inInclusiveRange(126.00, 126.20));
      }
    });
  });

  group('GeofenceTrackerProvider', () {
    test('initializes with default Lianga spots and valid current position', () {
      final provider = GeofenceTrackerProvider();
      expect(provider.locations.length, greaterThanOrEqualTo(5));
      expect(provider.currentPosition, isNotNull);
      expect(provider.trackingMode, TrackingMode.manual);
    });

    test('triggers enter and exit events upon movement', () {
      final provider = GeofenceTrackerProvider();
      final morenoCompound = provider.locations.firstWhere((l) => l.id == 'loc_moreno_compound');

      // Move user directly to Moreno Compound coordinates
      provider.setManualPosition(morenoCompound.point);

      expect(provider.isInsideGeofence(morenoCompound.id), isTrue);
      expect(provider.activeGeofenceIds.contains(morenoCompound.id), isTrue);

      final enterEvents = provider.eventLogs.where((e) => e.isEnter && e.locationId == morenoCompound.id);
      expect(enterEvents.isNotEmpty, isTrue);

      // Move user 2 km away (outside any geofence)
      provider.setManualPosition(const LatLng(8.6500, 126.1100));

      expect(provider.isInsideGeofence(morenoCompound.id), isFalse);
      final exitEvents = provider.eventLogs.where((e) => e.isExit && e.locationId == morenoCompound.id);
      expect(exitEvents.isNotEmpty, isTrue);
    });

    test('adds custom undiscovered spot and detects user inside it', () {
      final provider = GeofenceTrackerProvider();
      final initialCount = provider.locations.length;

      const customPoint = LatLng(8.6350, 126.0960);
      provider.addCustomSpot(
        name: 'Secret Sunset Rooftop',
        localTag: 'Purok 1, Poblacion, Lianga',
        category: 'Private Rooftop',
        description: 'Private rooftop deck overlooking the bay.',
        hiddenDetails: 'Family rooftop access through rear stairwell.',
        point: customPoint,
        radiusMeters: 50.0,
      );

      expect(provider.locations.length, equals(initialCount + 1));

      // Teleport to new spot
      provider.setManualPosition(customPoint);
      final added = provider.locations.last;
      expect(provider.isInsideGeofence(added.id), isTrue);
    });

    test('breadcrumbs record path history', () {
      final provider = GeofenceTrackerProvider();
      final initialCount = provider.breadcrumbs.length;

      provider.setManualPosition(const LatLng(8.6310, 126.0935));
      provider.setManualPosition(const LatLng(8.6320, 126.0945));

      expect(provider.breadcrumbs.length, equals(initialCount + 2));
    });

    test('clearing audit logs resets history', () {
      final provider = GeofenceTrackerProvider();
      final loc = provider.locations.first;
      provider.setManualPosition(loc.point);
      expect(provider.eventLogs.isNotEmpty, isTrue);

      provider.clearLogs();
      expect(provider.eventLogs.isEmpty, isTrue);
    });
  });
}
