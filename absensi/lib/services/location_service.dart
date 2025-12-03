import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/constants.dart';
import 'dart:math' show cos, sqrt, asin;

class LocationService {
  Future<bool> isLocationPermissionGranted() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }
  
  Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }
  
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }
  
  Future<Position> getCurrentLocation() async {
    if (!await isLocationServiceEnabled()) {
      throw Exception('GPS tidak aktif. Silakan aktifkan GPS di pengaturan.');
    }
    
    if (!await isLocationPermissionGranted()) {
      final granted = await requestLocationPermission();
      if (!granted) {
        throw Exception('Izin lokasi ditolak. Silakan berikan izin di pengaturan aplikasi.');
      }
    }
    
    // Use high accuracy for GPS without requiring WiFi
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      forceAndroidLocationManager: true, // Force GPS even without WiFi
      timeLimit: const Duration(seconds: 10),
    );
  }
  
  double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) *
            cos(lat2 * p) *
            (1 - cos((lon2 - lon1) * p)) /
            2;
    return 12742 * asin(sqrt(a)) * 1000;
  }
  
  Future<ValidLocationCheck> checkIfInValidLocation() async {
    final position = await getCurrentLocation();
    
    for (final loc in AppConstants.validLocations) {
      final distance = calculateDistance(
        position.latitude,
        position.longitude,
        loc['lat'],
        loc['lng'],
      );
      
      if (distance <= loc['radius']) {
        return ValidLocationCheck(
          isValid: true,
          locationName: loc['name'],
          distance: distance,
          latitude: position.latitude,
          longitude: position.longitude,
        );
      }
    }
    
    String nearest = '';
    double minDist = double.infinity;
    
    for (final loc in AppConstants.validLocations) {
      final distance = calculateDistance(
        position.latitude,
        position.longitude,
        loc['lat'],
        loc['lng'],
      );
      
      if (distance < minDist) {
        minDist = distance;
        nearest = loc['name'];
      }
    }
    
    return ValidLocationCheck(
      isValid: false,
      locationName: nearest,
      distance: minDist,
      latitude: position.latitude,
      longitude: position.longitude,
      message: '${minDist.toStringAsFixed(0)}m dari $nearest',
    );
  }
  
  String getLocationName(double latitude, double longitude) {
    for (final loc in AppConstants.validLocations) {
      final distance = calculateDistance(latitude, longitude, loc['lat'], loc['lng']);
      if (distance <= loc['radius']) return loc['name'];
    }
    return 'Unknown';
  }
}

class ValidLocationCheck {
  final bool isValid;
  final String locationName;
  final double distance;
  final double latitude;
  final double longitude;
  final String? message;
  
  ValidLocationCheck({
    required this.isValid,
    required this.locationName,
    required this.distance,
    required this.latitude,
    required this.longitude,
    this.message,
  });
}
