import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:ulab_bus/core/logger.dart';
import 'package:ulab_bus/core/models.dart';
import 'package:ulab_bus/services/supabase_service.dart';
import 'package:ulab_bus/services/location_service.dart';

class BusMap extends StatefulWidget {
  final String userType;
  final String userId;
  final String? busNumber;
  final bool? isTripActive;
  final Function(bool)? onTripStatusChanged;
  final VoidCallback? onBookTicket;

  const BusMap({
    super.key,
    required this.userType,
    required this.userId,
    this.busNumber,
    this.isTripActive,
    this.onTripStatusChanged,
    this.onBookTicket,
  });

  @override
  State<BusMap> createState() => _BusMapState();
}

class _BusMapState extends State<BusMap> {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  List<BusLocation> _busLocations = [];
  List<Alert> _recentAlerts = [];
  bool _isLoading = true;
  Position? _currentPosition;
  bool _isTrackingLocation = false;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      // Initialize location service
      await _locationService.initializeLocationService();

      // Get current location
      _currentPosition = await _locationService.getCurrentLocation();

      // Initialize real-time data
      _initializeRealTimeData();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('Failed to initialize map', tag: 'BUS_MAP', error: e);
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _initializeRealTimeData() {
    // Subscribe to real-time bus locations
    SupabaseService().getBusLocationsStream().listen((locations) {
      if (mounted) {
        setState(() {
          _busLocations = locations;
        });
      }
    });

    // Load initial alerts
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    try {
      final alerts = await SupabaseService().getRecentAlerts();
      if (mounted) {
        setState(() {
          _recentAlerts = alerts;
        });
      }
    } catch (e) {
      AppLogger.error('Failed to load alerts', tag: 'BUS_MAP', error: e);
    }
  }

  Future<void> _updateMyLocation() async {
    try {
      final position = await _locationService.getCurrentLocation();
      if (position != null && mounted) {
        setState(() {
          _currentPosition = position;
        });

        // Center map on new location
        _mapController.move(
          LatLng(position.latitude, position.longitude),
          15.0,
        );
      }
    } catch (e) {
      AppLogger.error('Failed to update location', tag: 'BUS_MAP', error: e);
    }
  }

  void _startLocationTracking() {
    if (_isTrackingLocation) return;

    _isTrackingLocation = true;
    _locationService.startLocationTracking(
      widget.busNumber ?? 'unknown',
      widget.userId,
          (location) {
        // Location updates will be handled by the stream
        AppLogger.debug('Location updated: ${location.latitude}, ${location.longitude}', tag: 'BUS_MAP');
      },
    );
  }

  void _stopLocationTracking() {
    _isTrackingLocation = false;
    _locationService.stopLocationTracking();
  }

  @override
  void dispose() {
    if (widget.userType == 'driver' && _isTrackingLocation) {
      _stopLocationTracking();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Map
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentPosition != null
                ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                : const LatLng(23.7500, 90.3615), // ULAB coordinates
            initialZoom: 15.0,
            maxZoom: 18.0,
            minZoom: 10.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.ulab.bus.system',
            ),

            // Current Location Marker
            if (_currentPosition != null)
              MarkerLayer(
                markers: [
                  Marker(
                    width: 40.0,
                    height: 40.0,
                    point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.blue,
                      size: 40.0,
                    ),
                  ),
                ],
              ),

            // Bus Location Markers
            MarkerLayer(
              markers: _busLocations.map((location) {
                return Marker(
                  width: 30.0,
                  height: 30.0,
                  point: LatLng(location.latitude, location.longitude),
                  child: const Icon(
                    Icons.directions_bus,
                    color: Colors.red,
                    size: 30.0,
                  ),
                );
              }).toList(),
            ),

            // ULAB Campus Marker
            MarkerLayer(
              markers: [
                Marker(
                  width: 30.0,
                  height: 30.0,
                  point: const LatLng(23.7500, 90.3615),
                  child: const Icon(
                    Icons.school,
                    color: Colors.green,
                    size: 30.0,
                  ),
                ),
              ],
            ),
          ],
        ),

        // Driver Controls
        if (widget.userType == 'driver') _buildDriverControls(),

        // Student Controls
        if (widget.userType == 'student') _buildStudentControls(),

        // Location Update Button
        Positioned(
          bottom: widget.userType == 'student' ? 100 : 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: _updateMyLocation,
            mini: true,
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            child: const Icon(Icons.my_location),
          ),
        ),

        // Loading Indicator
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }

  Widget _buildDriverControls() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Card(
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    widget.isTripActive == true
                        ? Icons.play_circle_fill
                        : Icons.pause_circle_filled,
                    color: widget.isTripActive == true ? Colors.green : Colors.grey,
                    size: 40,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isTripActive == true ? 'Trip Active' : 'Trip Inactive',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Bus ${widget.busNumber}',
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                        if (_currentPosition != null)
                          Text(
                            'Location: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          final newStatus = !(widget.isTripActive == true);
                          widget.onTripStatusChanged?.call(newStatus);

                          if (newStatus) {
                            _startLocationTracking();
                          } else {
                            _stopLocationTracking();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.isTripActive == true ? Colors.red : Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(widget.isTripActive == true ? 'END TRIP' : 'START TRIP'),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _updateMyLocation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('UPDATE LOCATION'),
                      ),
                    ],
                  ),
                ],
              ),
              if (_isTrackingLocation)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Location tracking active',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentControls() {
    return Positioned(
      bottom: 16,
      right: 16,
      child: Column(
        children: [
          FloatingActionButton(
            onPressed: widget.onBookTicket,
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            child: const Icon(Icons.confirmation_number),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () {
              if (_currentPosition != null) {
                _mapController.move(
                  LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                  15.0,
                );
              } else {
                _mapController.move(const LatLng(23.7500, 90.3615), 15.0);
              }
            },
            mini: true,
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }
}