import 'dart:async'; // Required for StreamSubscription
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ulab_bus/core/logger.dart';
import 'package:ulab_bus/core/models.dart';
import 'package:ulab_bus/services/supabase_service.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  bool _isTracking = false;
  Position? _lastPosition;

  // FIX: Store the Subscription so we can cancel it later
  StreamSubscription<Position>? _positionStreamSubscription;

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

  // Helper for Student App
  Stream<Position> getStudentLocationStream() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );
    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }

  Future<Position?> getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      _lastPosition = position;
      return position;
    } catch (e) {
      AppLogger.error('Failed to get current location', tag: 'LOCATION', error: e);
      return _lastPosition;
    }
  }

  // FIX: Changed to async to allow proper cancellation
  void startLocationTracking(String busId, String driverId, Function(BusLocation) onLocationUpdate) async {
    if (_isTracking) {
      AppLogger.warning('Location tracking already started', tag: 'LOCATION');
      return;
    }

    AppLogger.info('Starting tracking for bus: $busId', tag: 'LOCATION');

    // Safety: Ensure any previous stream is killed
    await _positionStreamSubscription?.cancel();

    _isTracking = true;
    _currentBusId = busId;
    _currentDriverId = driverId;

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    // FIX: Assign the subscription to the variable
    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) async {

      final busLocation = BusLocation(
        id: busId,
        busId: busId,
        driverId: driverId,
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
        speed: position.speed,
        heading: position.heading,
      );

      // Update local state
      onLocationUpdate(busLocation);
      _lastPosition = position;

      // Send to Supabase
      await SupabaseService().updateBusLocation(busLocation);
    });

    AppLogger.success('Location tracking started', tag: 'LOCATION');
  }

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

  // FIX: Changed to Future<void> to allow await
  Future<void> stopLocationTracking() async {
    if (_currentBusId != null) {
      await clearBusLocation(_currentBusId!);
    }

    AppLogger.info('Stopping location tracking...', tag: 'LOCATION');

    // FIX: Actually cancel the listener
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;

    _isTracking = false;
    _currentBusId = null;
    _currentDriverId = null;
    AppLogger.success('Location tracking stopped', tag: 'LOCATION');
  }

  bool get isTracking => _isTracking;
  Position? get lastPosition => _lastPosition;
  String? get currentBusId => _currentBusId;
}