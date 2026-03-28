import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum LocationStatus { present, wfh, permissionDenied, error }

class LocationService {
  final _client = Supabase.instance.client;

  Future<LocationResult> getAttendanceStatus() async {
    try {
      print('📍 STEP 1: Checking GPS service...');
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print('📍 STEP 1: serviceEnabled=$serviceEnabled');

      final permission = await _checkPermission();
      print('📍 STEP 2: permission=$permission');

      if (permission != null) {
        return LocationResult(
          status: LocationStatus.permissionDenied,
          message: permission,
        );
      }

      print('📍 STEP 3: Getting GPS position...');
      // WHY locationSettings: geolocator 14.x moved params into
      // LocationSettings object — old named params removed in 14.x
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      print('📍 STEP 3: lat=${position.latitude} lng=${position.longitude}');

      print('📍 STEP 4: Fetching office from Supabase...');
      final officeData = await _client
          .from('office_settings')
          .select('lat, lng, radius_km')
          .single();
      print('📍 STEP 4: officeData=$officeData');

      // ✅ toDouble() handles both int and double from Supabase
      final officeLat = (officeData['lat'] as num).toDouble();
      final officeLng = (officeData['lng'] as num).toDouble();
      final radiusKm = (officeData['radius_km'] as num).toDouble();

      final distanceMeters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        officeLat,
        officeLng,
      );
      final distanceKm = distanceMeters / 1000;
      print(
        '📍 STEP 5: distance=${distanceKm.toStringAsFixed(2)}km radius=${radiusKm}km',
      );

      final status = distanceKm <= radiusKm
          ? LocationStatus.present
          : LocationStatus.wfh;
      print('📍 STEP 6: Final status=$status');

      return LocationResult(
        status: status,
        lat: position.latitude,
        lng: position.longitude,
        distanceKm: distanceKm,
        message: status == LocationStatus.present
            ? 'You are at office (${distanceKm.toStringAsFixed(2)} km)'
            : 'Working from home (${distanceKm.toStringAsFixed(2)} km from office)',
      );
    } catch (e, st) {
      print('📍 ERROR: $e');
      print('📍 STACK: $st');
      return LocationResult(
        status: LocationStatus.error,
        message: 'Location error: $e',
      );
    }
  }

  Future<String?> _checkPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return 'GPS is turned off. Please enable location services.';
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return 'Location permission denied. Please allow location access.';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return 'Location permanently denied. Go to Settings → enable Location.';
    }

    return null;
  }
}

class LocationResult {
  final LocationStatus status;
  final double? lat;
  final double? lng;
  final double? distanceKm;
  final String message;

  const LocationResult({
    required this.status,
    this.lat,
    this.lng,
    this.distanceKm,
    required this.message,
  });
}
