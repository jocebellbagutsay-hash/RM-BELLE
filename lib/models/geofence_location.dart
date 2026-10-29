import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Represents a custom secret or personal location that is not visible on commercial maps.
class GeofenceLocation {
  GeofenceLocation({
    required this.id,
    required this.name,
    required this.localTag,
    required this.category,
    required this.description,
    required this.hiddenDetails,
    required this.point,
    required this.radiusMeters,
    required this.icon,
    required this.accentColor,
    this.isCustom = false,
  });

  final String id;
  final String name;
  final String localTag;
  final String category;
  final String description;
  final String hiddenDetails;
  final LatLng point;
  double radiusMeters;
  final IconData icon;
  final Color accentColor;
  final bool isCustom;

  double get latitude => point.latitude;
  double get longitude => point.longitude;

  GeofenceLocation copyWith({
    String? id,
    String? name,
    String? localTag,
    String? category,
    String? description,
    String? hiddenDetails,
    LatLng? point,
    double? radiusMeters,
    IconData? icon,
    Color? accentColor,
    bool? isCustom,
  }) {
    return GeofenceLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      localTag: localTag ?? this.localTag,
      category: category ?? this.category,
      description: description ?? this.description,
      hiddenDetails: hiddenDetails ?? this.hiddenDetails,
      point: point ?? this.point,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      icon: icon ?? this.icon,
      accentColor: accentColor ?? this.accentColor,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  /// Default authentic custom locations in Lianga, Surigao del Sur
  /// based on the user's custom designated spots.
  static List<GeofenceLocation> getLiangaLocations() {
    return [
      GeofenceLocation(
        id: 'loc_bus_stop',
        name: 'Bus Stop (Sabang Junction)',
        localTag: 'Corner F. De Castro St & Coastal Rd, Purok 4, Sabang, Lianga',
        category: 'Transit & Commuter Stop',
        description:
            'Designated commuter waiting and boarding stop at the junction of F. De Castro Street and the Surigao-Davao Coastal Road.',
        hiddenDetails:
            'A vital everyday commuter boarding corner used by Sabang and Purok 4 residents for provincial buses and vans; unmarked on commercial navigation maps.',
        point: const LatLng(8.63615, 126.09335),
        radiusMeters: 40.0,
        icon: Icons.directions_bus_rounded,
        accentColor: const Color(0xFF2563EB), // Blue
      ),
      GeofenceLocation(
        id: 'loc_covered_court',
        name: 'Lianga Covered Court',
        localTag: 'Near Public Market & Terminal, Poblacion, Lianga',
        category: 'Sports & Community Gym',
        description:
            'The central municipal covered sports gymnasium adjacent to the Lianga Public Market and Traysikad Terminal.',
        hiddenDetails:
            'The primary venue for inter-barangay basketball tournaments, festivals, and assemblies, tucked behind Ronquillo St without a dedicated pin on standard maps.',
        point: const LatLng(8.63205, 126.09495),
        radiusMeters: 50.0,
        icon: Icons.sports_basketball_rounded,
        accentColor: const Color(0xFFEA580C), // Orange
      ),
      GeofenceLocation(
        id: 'loc_public_cemetery',
        name: 'Lianga Public Cemetery',
        localTag: 'Tagago / Purok 1, Poblacion, Lianga',
        category: 'Memorial Grounds',
        description:
            'The municipal public cemetery of Lianga situated in Tagago / Purok 1, Poblacion, serving as the resting grounds for generations of Lianga families.',
        hiddenDetails:
            'A solemn community memorial ground located in Tagago / Purok 1 south of Layno Street, tucked behind the residential lane toward the coastal area.',
        point: const LatLng(8.62843, 126.09561),
        radiusMeters: 50.0,
        icon: Icons.account_balance_rounded,
        accentColor: const Color(0xFF64748B), // Slate Grey
      ),
      GeofenceLocation(
        id: 'loc_moreno_compound',
        name: 'Moreno Compound',
        localTag: 'East of Ronquillo St, Poblacion, Lianga',
        category: 'Private Residence',
        description:
            'A quiet private family residential compound tucked between Ronquillo Street and the coastline, north of Hazel\'s Bakeshop.',
        hiddenDetails:
            'Private ancestral family living quarters shielded by trees and greenery; intentionally not searchable on Google Maps to maintain privacy.',
        point: const LatLng(8.63335, 126.09515),
        radiusMeters: 45.0,
        icon: Icons.home_rounded,
        accentColor: const Color(0xFFE11D48), // Rose / Red
      ),
      GeofenceLocation(
        id: 'loc_tambayanan_tsikahanan',
        name: 'Tambayanan / Tsikahanan',
        localTag: 'Seaside behind Police Station & Travellers Inn, Lianga',
        category: 'Undiscovered Hangout',
        description:
            'A relaxed seaside shoreline gathering spot located right by the water behind the Lianga Police Station and Travellers Inn.',
        hiddenDetails:
            'A favorite local seaside tambayan where friends gather to chitchat ("tsika"), enjoy afternoon snacks, and watch the waves away from main street noise.',
        point: const LatLng(8.63105, 126.09580),
        radiusMeters: 40.0,
        icon: Icons.forum_rounded,
        accentColor: const Color(0xFF059669), // Emerald
      ),
    ];
  }
}

/// Geofence transition event types
enum GeofenceEventType {
  enter,
  exit,
}

/// A logged geofence transition event
class GeofenceEvent {
  GeofenceEvent({
    required this.id,
    required this.locationId,
    required this.locationName,
    required this.type,
    required this.timestamp,
    required this.distanceMeters,
    required this.userPoint,
    this.notes = '',
  });

  final String id;
  final String locationId;
  final String locationName;
  final GeofenceEventType type;
  final DateTime timestamp;
  final double distanceMeters;
  final LatLng userPoint;
  final String notes;

  bool get isEnter => type == GeofenceEventType.enter;
  bool get isExit => type == GeofenceEventType.exit;
}
