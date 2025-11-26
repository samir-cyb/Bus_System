import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart'; // Added import
import 'package:ulab_bus/core/logger.dart';
import 'package:ulab_bus/core/models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:ulab_bus/services/location_service.dart'; // Added import

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

  // User Location (The Blue Dot)
  Position? _myLocation;

  // Alert & Ticket Logic
  List<Map<String, dynamic>> _rawAlerts = [];
  List<Map<String, dynamic>> _visibleAlerts = [];
  String? _myActiveBusId;

  StreamSubscription? _ticketSubscription;
  StreamSubscription? _alertSubscription;
  StreamSubscription? _myLocationSubscription;

  bool _isLoadingRoutes = true;
  final LatLng _ulabLocation = const LatLng(23.7629, 90.3582);

  @override
  void initState() {
    super.initState();
    _loadRoutes();
    _listenToBusLocations();
    _listenToMyLocation(); // Start tracking student location

    if (widget.userType == 'student') {
      _listenToMyActiveTicket();
    }
    _listenToAlerts();
  }

  @override
  void dispose() {
    _ticketSubscription?.cancel();
    _alertSubscription?.cancel();
    _myLocationSubscription?.cancel();
    super.dispose();
  }

  // 0. LISTEN TO MY LOCATION (Blue Dot)
  void _listenToMyLocation() {
    _myLocationSubscription = LocationService().getStudentLocationStream().listen((pos) {
      if (mounted) {
        setState(() {
          _myLocation = pos;
        });
      }
    });
  }

  // 1. TICKET LISTENER
  void _listenToMyActiveTicket() {
    _ticketSubscription = _supabase
        .from('tickets')
        .stream(primaryKey: ['id'])
        .eq('student_id', widget.userId)
        .order('purchase_time', ascending: false)
        .limit(1)
        .listen((data) {
      String? foundBusId;
      if (data.isNotEmpty) {
        final ticket = data.first;
        final isUsed = ticket['is_used'] == true;
        final purchaseTime = DateTime.parse(ticket['purchase_time']).toLocal();
        final isRecent = DateTime.now().difference(purchaseTime).inHours < 24;

        if (!isUsed && isRecent) {
          foundBusId = ticket['bus_id'];
        }
      }
      if (mounted) {
        setState(() { _myActiveBusId = foundBusId; });
        _filterAlerts();
      }
    });
  }

  // 2. ALERT LISTENER
  void _listenToAlerts() {
    _alertSubscription = _supabase
        .from('alerts')
        .stream(primaryKey: ['id'])
        .order('timestamp', ascending: false)
        .limit(5)
        .listen((data) {
      if (mounted) {
        bool isNewAlertIncoming = false;
        if (_rawAlerts.isNotEmpty && data.isNotEmpty) {
          if (data.first['id'] != _rawAlerts.first['id']) isNewAlertIncoming = true;
        } else if (_rawAlerts.isEmpty && data.isNotEmpty) {
          isNewAlertIncoming = true;
        }
        setState(() { _rawAlerts = data; });
        _filterAlerts(checkTime: isNewAlertIncoming);
      }
    });
  }

  // 3. FILTER LOGIC
  void _filterAlerts({bool checkTime = false}) {
    List<Map<String, dynamic>> filtered = [];
    if (widget.userType == 'student') {
      if (_myActiveBusId == null) {
        filtered = [];
      } else {
        filtered = _rawAlerts.where((alert) => alert['bus_id'] == _myActiveBusId).toList();
      }
    } else {
      filtered = _rawAlerts;
    }

    setState(() { _visibleAlerts = filtered; });

    if (checkTime && filtered.isNotEmpty) {
      final latestAlert = filtered.first;
      final alertTime = DateTime.parse(latestAlert['timestamp']).toLocal();
      if (DateTime.now().difference(alertTime).inMinutes < 5) {
        if (_rawAlerts.isNotEmpty && latestAlert['id'] == _rawAlerts.first['id']) {
          _showSnackBar(latestAlert);
        }
      }
    }
  }

  void _showSnackBar(Map<String, dynamic> alert) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text("${alert['alert_type']}: ${alert['message']}", style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        backgroundColor: Colors.red[700],
        duration: const Duration(seconds: 6),
        action: SnackBarAction(label: 'VIEW', textColor: Colors.white, onPressed: _showAlertsDialog),
      ),
    );
  }

  // --- MAP UI ---

  Future<void> _loadRoutes() async {
    try {
      final response = await _supabase.from('bus_routes').select().eq('is_active', true);
      final routes = (response as List).map((data) => BusRoute.fromMap(data)).toList();
      if (mounted) setState(() => _routes = routes);
    } catch (e) {}
  }

  Future<void> _onRouteSelected(BusRoute? route) async {
    if (route == null) return;
    setState(() { _selectedRoute = route; _routePoints = []; });
    try {
      final response = await _supabase.from('stops').select().eq('route_id', route.id).order('stop_order', ascending: true);
      final stops = (response as List).map((data) => BusStop.fromMap(data)).toList();
      if (stops.isNotEmpty) {
        setState(() {
          _routePoints = stops.map((s) => LatLng(s.latitude, s.longitude)).toList();
        });
        _mapController.move(_routePoints.first, 13.0);
      }
    } catch (e) {}
  }

  void _listenToBusLocations() {
    _supabase.from('bus_locations').stream(primaryKey: ['id']).listen((data) {
      if (mounted) {
        final now = DateTime.now();
        final validLocations = data.where((loc) {
          final locTime = DateTime.parse(loc['timestamp']);
          return now.difference(locTime).inMinutes < 5;
        }).map((map) => BusLocation.fromMap(map)).toList();
        setState(() => _activeBuses = validLocations);
      }
    });
  }

  void _showAlertsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Recent Alerts"),
        content: SizedBox(
          width: double.maxFinite,
          child: _visibleAlerts.isEmpty
              ? const Text("No active alerts.")
              : ListView.builder(
            shrinkWrap: true,
            itemCount: _visibleAlerts.length,
            itemBuilder: (context, index) {
              final alert = _visibleAlerts[index];
              final time = DateTime.parse(alert['timestamp']).toLocal();
              return ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.orange),
                title: Text(alert['alert_type'] ?? 'Alert'),
                subtitle: Text("${alert['message']}\n${DateFormat('h:mm a').format(time)}", style: const TextStyle(fontSize: 12)),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("CLOSE"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(initialCenter: _ulabLocation, initialZoom: 13.0),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.ulab.bus.system'),

            // Student Location (Blue Dot)
            if (_myLocation != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(_myLocation!.latitude, _myLocation!.longitude),
                    width: 20, height: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)],
                      ),
                    ),
                  ),
                ],
              ),

            if (_routePoints.isNotEmpty) PolylineLayer(polylines: [Polyline(points: _routePoints, strokeWidth: 5.0, color: Colors.blueAccent)]),
            if (_routePoints.isNotEmpty) MarkerLayer(markers: _routePoints.map((point) => Marker(point: point, width: 12, height: 12, child: Container(decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle)))).toList()),
            MarkerLayer(markers: _activeBuses.map((bus) => Marker(point: LatLng(bus.latitude, bus.longitude), width: 40, height: 40, child: const Icon(Icons.directions_bus, color: Colors.red, size: 40))).toList()),
            MarkerLayer(markers: [Marker(point: _ulabLocation, width: 45, height: 45, child: const Column(children: [Icon(Icons.school, color: Colors.green, size: 30), Text("ULAB", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))]))]),
          ],
        ),

        // Status Pill
        Positioned(
          top: 50, left: 0, right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _myActiveBusId != null ? Colors.green[800] : Colors.grey[800],
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_myActiveBusId != null ? Icons.confirmation_number : Icons.confirmation_number_outlined, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    _myActiveBusId != null ? "Tracking Bus: $_myActiveBusId" : "No Active Ticket",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Route Selector
        Positioned(
          top: 100, left: 16, right: 70,
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

        // Alert Icon
        if (_visibleAlerts.isNotEmpty)
          Positioned(
            top: 100, right: 16,
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
                    child: Text('${_visibleAlerts.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          ),

        // Recenter & My Location Button
        Positioned(
          bottom: 100, right: 16,
          child: FloatingActionButton(
            heroTag: "recenter", mini: true, backgroundColor: Colors.white,
            onPressed: () {
              if (_myLocation != null) {
                _mapController.move(LatLng(_myLocation!.latitude, _myLocation!.longitude), 15.0);
              } else {
                _mapController.move(_ulabLocation, 13.0);
              }
            },
            child: const Icon(Icons.my_location, color: Colors.blue),
          ),
        ),

        if (widget.userType == 'student')
          Positioned(
            bottom: 20, left: 50, right: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
              onPressed: () { widget.onBookTicket?.call(); },
              icon: const Icon(Icons.confirmation_number),
              label: const Text("BOOK TICKET"),
            ),
          ),
      ],
    );
  }
}