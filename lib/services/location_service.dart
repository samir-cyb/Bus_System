import 'package:geolocator/geolocator.dart';
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

      // Check permissions
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

      // Check if location service is enabled
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
      AppLogger.debug('Getting current location...', tag: 'LOCATION');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      _lastPosition = position;
      AppLogger.debug('Location acquired: ${position.latitude}, ${position.longitude}', tag: 'LOCATION');
      return position;
    } catch (e) {
      AppLogger.error('Failed to get current location', tag: 'LOCATION', error: e);
      return null;
    }
  }

  void startLocationTracking(String busId, String driverId, Function(BusLocation) onLocationUpdate) {
    if (_isTracking) {
      AppLogger.warning('Location tracking already started', tag: 'LOCATION');
      return;
    }

    AppLogger.info('Starting location tracking for bus: $busId', tag: 'LOCATION');
    _isTracking = true;
    _currentBusId = busId;
    _currentDriverId = driverId;

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 10, // meters
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings);
    _positionStream?.listen((Position position) async {
      AppLogger.debug('Location update: ${position.latitude}, ${position.longitude}', tag: 'LOCATION');

      final busLocation = BusLocation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
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

      // Send to Supabase for real-time sharing
      await SupabaseService().updateBusLocation(busLocation);
    });

    AppLogger.success('Location tracking started', tag: 'LOCATION');
  }

  void stopLocationTracking() {
    AppLogger.info('Stopping location tracking...', tag: 'LOCATION');
    _isTracking = false;
    _positionStream = null;
    _currentBusId = null;
    _currentDriverId = null;
    AppLogger.success('Location tracking stopped', tag: 'LOCATION');
  }

  bool get isTracking => _isTracking;
  Position? get lastPosition => _lastPosition;
  String? get currentBusId => _currentBusId;
}