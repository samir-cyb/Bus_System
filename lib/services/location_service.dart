import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Added this import
import 'package:ulab_bus/core/logger.dart';
import 'package:ulab_bus/core/models.dart';
import 'package:ulab_bus/services/supabase_service.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  bool _isTracking = false;
  Position? _lastPosition;
  Stream<Position>? _positionStream;
  String? _currentBusId;
  String? _currentDriverId;

  Future<bool> initializeLocationService() async {
    try {
      AppLogger.info('Initializing location service...', tag: 'LOCATION');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          AppLogger.error('Location permissions denied', tag: 'LOCATION');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        AppLogger.error('Location permissions permanently denied', tag: 'LOCATION');
        return false;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        AppLogger.warning('Location services are disabled', tag: 'LOCATION');
        return false;
      }

      AppLogger.success('Location service initialized successfully', tag: 'LOCATION');
      return true;
    } catch (e) {
      AppLogger.error('Failed to initialize location service', tag: 'LOCATION', error: e);
      return false;
    }
  }

  Future<Position?> getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      _lastPosition = position;
      return position;
    } catch (e) {
      AppLogger.error('Failed to get current location', tag: 'LOCATION', error: e);
      return null;
    }
  }

  void startLocationTracking(String busId, String driverId, Function(BusLocation) onLocationUpdate) {
    if (_isTracking) return;

    AppLogger.info('Starting tracking for bus: $busId', tag: 'LOCATION');
    _isTracking = true;
    _currentBusId = busId;
    _currentDriverId = driverId;

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 10,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings);
    _positionStream?.listen((Position position) async {
      // 1. Create Location Object
      final busLocation = BusLocation(
        id: busId, // USE BUS ID AS KEY so we don't create duplicates
        busId: busId,
        driverId: driverId,
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
        speed: position.speed,
        heading: position.heading,
      );

      // 2. Local Update
      onLocationUpdate(busLocation);
      _lastPosition = position;

      // 3. Database Update
      await SupabaseService().updateBusLocation(busLocation);
    });
  }

  // NEW: Deletes the location from database so the bus disappears from map
  Future<void> clearBusLocation(String busId) async {
    try {
      await Supabase.instance.client
          .from('bus_locations')
          .delete()
          .eq('bus_id', busId);
      AppLogger.success('Cleared location for bus: $busId', tag: 'LOCATION');
    } catch (e) {
      AppLogger.error('Failed to clear location', tag: 'LOCATION', error: e);
    }
  }

  void stopLocationTracking() {
    if (_currentBusId != null) {
      clearBusLocation(_currentBusId!); // Clean up database
    }

    AppLogger.info('Stopping location tracking...', tag: 'LOCATION');
    _isTracking = false;
    _positionStream = null;
    _currentBusId = null;
    _currentDriverId = null;
  }

  bool get isTracking => _isTracking;
  Position? get lastPosition => _lastPosition;
}