import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  // Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  // Check location permissions
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  // Request location permission
  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  // Get current location with retry and fallback to last known position
  Future<Position?> getCurrentLocation({int retries = 2}) async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled, trying last known position');
      return await _getLastKnownPosition();
    }

    // Check permission status
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permissions denied, trying last known position');
        return await _getLastKnownPosition();
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permissions permanently denied, trying last known position');
      return await _getLastKnownPosition();
    }

    // Get current position with timeout and retry logic
    for (int i = 0; i < retries; i++) {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 100,
          ),
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Location request timeout');
          },
        );
        return position;
      } catch (e) {
        debugPrint('Location attempt ${i + 1} failed: $e');
        if (i == retries - 1) {
          // Last attempt failed, try last known position
          return await _getLastKnownPosition();
        }
        // Wait before retry
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    
    return null;
  }

  // Get last known position as fallback
  Future<Position?> _getLastKnownPosition() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        debugPrint('Using last known position: ${position.latitude}, ${position.longitude}');
      }
      return position;
    } catch (e) {
      debugPrint('Error getting last known position: $e');
      return null;
    }
  }

  // Get location name from coordinates (you can use reverse geocoding API if needed)
  String formatCoordinates(double lat, double lon) {
    return '${lat.toStringAsFixed(2)}°, ${lon.toStringAsFixed(2)}°';
  }
}
