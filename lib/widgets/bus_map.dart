import 'dart:async'; // Needed for Timer
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:ulab_bus/core/logger.dart';
import 'package:ulab_bus/core/models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class BusMap extends StatefulWidget {
  final String userType;
  final String userId;
  final VoidCallback? onBookTicket;

  const BusMap({
    super.key,
    required this.userType,
    required this.userId,
    this.onBookTicket,
  });

  @override
  State<BusMap> createState() => _BusMapState();
}

class _BusMapState extends State<BusMap> {
  final MapController _mapController = MapController();
  final _supabase = Supabase.instance.client;

  // State Variables
  List<BusRoute> _routes = [];
  BusRoute? _selectedRoute;
  List<LatLng> _routePoints = [];
  List<BusLocation> _activeBuses = [];
  List<Map<String, dynamic>> _activeAlerts = [];

  // Logic for filtering alerts
  String? _myActiveBusId;
  Timer? _ticketCheckTimer; // Timer to keep checking ticket status

  bool _isLoadingRoutes = true;
  final LatLng _ulabLocation = const LatLng(23.7629, 90.3582);

  @override
  void initState() {
    super.initState();
    _loadRoutes();
    _listenToBusLocations();

    // Initial check
    _checkTicketAndSetupAlerts();

    // Set up a timer to re-check ticket status every 60 seconds
    if (widget.userType == 'student') {
      _ticketCheckTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
        _fetchActiveTicket();
      });
    }
  }

  @override
  void didUpdateWidget(BusMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // CRITICAL: When parent rebuilds (e.g. returning from booking), re-check ticket!
    if (widget.userType == 'student') {
      _fetchActiveTicket();
    }
  }

  @override
  void dispose() {
    _ticketCheckTimer?.cancel();
    super.dispose();
  }

  void _checkTicketAndSetupAlerts() {
    if (widget.userType == 'student') {
      _fetchActiveTicket();
    }
    // Always start listening, but the listener itself handles the filtering logic
    _listenToAlerts();
  }

  Future<void> _fetchActiveTicket() async {
    try {
      // Look for a ticket purchased in the last 12 hours
      final twelveHoursAgo = DateTime.now().subtract(const Duration(hours: 12));

      final response = await _supabase
          .from('tickets')
          .select()
          .eq('student_id', widget.userId)
          .gt('purchase_time', twelveHoursAgo.toIso8601String())
          .order('purchase_time', ascending: false)
          .limit(1)
          .maybeSingle();

      if (mounted) {
        setState(() {
          if (response != null) {
            _myActiveBusId = response['bus_id'];
            AppLogger.debug("Active Ticket found for: $_myActiveBusId", tag: "BUS_MAP");
          } else {
            _myActiveBusId = null;
            // If ticket expired or doesn't exist, clear alerts immediately
            _activeAlerts = [];
            AppLogger.debug("No active ticket found.", tag: "BUS_MAP");
          }
        });
      }
    } catch (e) {
      AppLogger.error('Failed to fetch active ticket', tag: 'BUS_MAP', error: e);
    }
  }

  Future<void> _loadRoutes() async {
    try {
      final response = await _supabase.from('bus_routes').select().eq('is_active', true);
      final routes = (response as List).map((data) => BusRoute.fromMap(data)).toList();

      if (mounted) {
        setState(() {
          _routes = routes;
          _isLoadingRoutes = false;
        });
      }
    } catch (e) {
      AppLogger.error('Failed to load routes', tag: 'BUS_MAP', error: e);
    }
  }

  Future<void> _onRouteSelected(BusRoute? route) async {
    if (route == null) return;

    setState(() {
      _selectedRoute = route;
      _routePoints = [];
    });

    try {
      final response = await _supabase
          .from('stops')
          .select()
          .eq('route_id', route.id)
          .order('stop_order', ascending: true);

      final stops = (response as List).map((data) => BusStop.fromMap(data)).toList();

      if (stops.isNotEmpty) {
        setState(() {
          _routePoints = stops.map((s) => LatLng(s.latitude, s.longitude)).toList();
        });
        _mapController.move(_routePoints.first, 13.0);
      }
    } catch (e) {
      AppLogger.error('Failed to load stops', tag: 'BUS_MAP', error: e);
    }
  }

  void _listenToBusLocations() {
    _supabase
        .from('bus_locations')
        .stream(primaryKey: ['id'])
        .listen((data) {
      if (mounted) {
        final locations = data.map((map) => BusLocation.fromMap(map)).toList();
        setState(() {
          _activeBuses = locations;
        });
      }
    });
  }

  void _listenToAlerts() {
    _supabase
        .from('alerts')
        .stream(primaryKey: ['id'])
        .order('timestamp', ascending: false)
        .limit(5)
        .listen((data) {
      if (mounted) {
        List<Map<String, dynamic>> relevantAlerts = data;

        // STRICT FILTERING LOGIC
        if (widget.userType == 'student') {
          if (_myActiveBusId == null || _myActiveBusId!.isEmpty) {
            // Scenario: Student has NO ticket.
            // Force empty list so NO alerts are shown.
            relevantAlerts = [];
          } else {
            // Scenario: Student HAS ticket.
            // Only allow alerts where bus_id matches the ticket's bus_id.
            relevantAlerts = data.where((alert) {
              return alert['bus_id'] == _myActiveBusId;
            }).toList();
          }
        }

        // Check for new alerts to show popup
        bool isNewAlert = false;
        if (relevantAlerts.isNotEmpty) {
          if (_activeAlerts.isEmpty) {
            // Check if it's recent (last 30 seconds)
            final alertTime = DateTime.parse(relevantAlerts.first['timestamp']);
            if (DateTime.now().difference(alertTime).inSeconds < 30) {
              isNewAlert = true;
            }
          } else if (relevantAlerts.first['id'] != _activeAlerts.first['id']) {
            isNewAlert = true;
          }
        }

        setState(() {
          _activeAlerts = relevantAlerts;
        });

        if (isNewAlert) {
          final newAlert = relevantAlerts.first;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("⚠️ Bus ${newAlert['bus_id']}: ${newAlert['alert_type']}"),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 6),
              action: SnackBarAction(label: 'VIEW', textColor: Colors.white, onPressed: _showAlertsDialog),
            ),
          );
        }
      }
    });
  }

  void _showAlertsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text("My Bus Alerts"),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: _activeAlerts.isEmpty
              ? const Text("No active alerts for your bus.")
              : ListView.builder(
            shrinkWrap: true,
            itemCount: _activeAlerts.length,
            itemBuilder: (context, index) {
              final alert = _activeAlerts[index];
              final time = DateTime.parse(alert['timestamp']);
              final timeStr = DateFormat('h:mm a').format(time);

              return ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.orange),
                title: Text(alert['alert_type'] ?? 'Alert'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alert['message'] ?? ''),
                    Text("$timeStr", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CLOSE")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Map Layer
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _ulabLocation,
            initialZoom: 13.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.ulab.bus.system',
            ),
            if (_routePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(points: _routePoints, strokeWidth: 5.0, color: Colors.blueAccent),
                ],
              ),
            if (_routePoints.isNotEmpty)
              MarkerLayer(
                markers: _routePoints.map((point) => Marker(
                  point: point, width: 12, height: 12,
                  child: Container(decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle)),
                )).toList(),
              ),
            MarkerLayer(
              markers: _activeBuses.map((bus) => Marker(
                point: LatLng(bus.latitude, bus.longitude), width: 40, height: 40,
                child: const Icon(Icons.directions_bus, color: Colors.red, size: 40),
              )).toList(),
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _ulabLocation, width: 45, height: 45,
                  child: const Column(children: [Icon(Icons.school, color: Colors.green, size: 30), Text("ULAB", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))]),
                ),
              ],
            ),
          ],
        ),

        // Route Selector
        Positioned(
          top: 50, left: 16, right: 70,
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: _isLoadingRoutes
                  ? const LinearProgressIndicator()
                  : DropdownButtonHideUnderline(
                child: DropdownButton<BusRoute>(
                  isExpanded: true,
                  hint: const Text("Select a Route"),
                  value: _selectedRoute,
                  items: _routes.map((route) => DropdownMenuItem(value: route, child: Text(route.name, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: _onRouteSelected,
                ),
              ),
            ),
          ),
        ),

        // Alert Icon (Only visible if there are alerts for MY bus)
        if (_activeAlerts.isNotEmpty)
          Positioned(
            top: 50, right: 16,
            child: Stack(
              children: [
                FloatingActionButton(
                  heroTag: "alerts", backgroundColor: Colors.white, onPressed: _showAlertsDialog, mini: true,
                  child: const Icon(Icons.notifications, color: Colors.orange),
                ),
                Positioned(
                  right: 0, top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text('${_activeAlerts.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          ),

        // Recenter Button
        Positioned(
          bottom: 100, right: 16,
          child: FloatingActionButton(
            heroTag: "recenter", mini: true, backgroundColor: Colors.white,
            onPressed: () { _mapController.move(_ulabLocation, 13.0); },
            child: const Icon(Icons.my_location, color: Colors.blue),
          ),
        ),

        // Book Ticket Button (Fixed Logic)
        if (widget.userType == 'student')
          Positioned(
            bottom: 20, left: 50, right: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.all(16),
              ),
              onPressed: () {
                // Correctly call the VoidCallback without await
                widget.onBookTicket?.call();
              },
              icon: const Icon(Icons.confirmation_number),
              label: const Text("BOOK TICKET"),
            ),
          ),
      ],
    );
  }
}