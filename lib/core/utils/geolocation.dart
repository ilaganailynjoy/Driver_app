import 'dart:math';

import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

/// GPS + navigation helpers. Returns null-safe values so the UI can degrade
/// gracefully when location is unavailable.
class Geolocation {
  Geolocation._();

  static Future<Position?> currentPosition() async {
    try {
      var serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Opens the Google Maps navigation app to a destination.
  static Future<bool> openNavigation(double lat, double lng) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Approximate straight-line distance between two coordinates (km).
  static double distanceInKm(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = pow(sin(dLat / 2), 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * pow(sin(dLng / 2), 2);
    return 2 * r * asin(sqrt(a.toDouble()));
  }

  static double _rad(double deg) => deg * pi / 180.0;
}