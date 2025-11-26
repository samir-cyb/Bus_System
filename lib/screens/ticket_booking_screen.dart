import 'package:flutter/material.dart';
import 'package:ulab_bus/core/logger.dart';
import 'package:ulab_bus/core/models.dart';
import 'package:ulab_bus/services/supabase_service.dart';

class TicketBookingScreen extends StatefulWidget {
  final String studentId;
  final String studentName;

  const TicketBookingScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<TicketBookingScreen> createState() => _TicketBookingScreenState();
}

class _TicketBookingScreenState extends State<TicketBookingScreen> {
  // Data Lists
  List<BusRoute> _routes = [];
  List<BusStop> _stops = [];
  List<Bus> _activeBuses = [];

  // Selections
  BusRoute? _selectedRoute;
  Bus? _selectedBus;
  BusStop? _selectedStartStop;
  BusStop? _selectedEndStop;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      // Load Routes and Buses in parallel
      final routesFuture = SupabaseService().getRoutes();
      final busesFuture = SupabaseService().getAvailableBuses();

      final results = await Future.wait([routesFuture, busesFuture]);

      if (mounted) {
        setState(() {
          _routes = results[0] as List<BusRoute>;
          _routes.sort((a, b) => a.name.compareTo(b.name));
          _activeBuses = results[1] as List<Bus>;
          _isLoading = false;
        });
      }
    } catch (e) {
      _showError('Failed to load data. Please check connection.');
      setState(() { _isLoading = false; });
    }
  }

  // When Route changes, fetch the specific stops for THAT route
  Future<void> _onRouteChanged(BusRoute? newRoute) async {
    // 1. Reset dependent selections immediately
    setState(() {
      _selectedRoute = newRoute;
      _stops = []; // Clear old stops
      _selectedStartStop = null;
      _selectedEndStop = null;
      // Note: We keep _selectedBus because your DB doesn't link Bus to Route yet
    });

    if (newRoute == null) return;

    // 2. Fetch new stops
    try {
      final stops = await SupabaseService().getStopsForRoute(newRoute.id);

      if (mounted) {
        setState(() {
          _stops = stops;
          if (stops.isEmpty) {
            _showError('No stops found for this route.');
          }
        });
      }
    } catch (e) {
      _showError('Failed to load stops.');
    }
  }

  double _calculateFare() {
    if (_selectedStartStop == null || _selectedEndStop == null) return 0.0;

    // Ensure we are using the fare_from_start logic
    final startFare = _selectedStartStop!.fareFromStart;
    final endFare = _selectedEndStop!.fareFromStart;

    // Simple distance based calculation
    return (endFare - startFare).abs();
  }

  Future<void> _bookTicket() async {
    if (_selectedRoute == null || _selectedBus == null ||
        _selectedStartStop == null || _selectedEndStop == null) {
      _showError('Please complete all selections');
      return;
    }

    // Validation: End stop must be after Start stop
    if (_selectedStartStop!.stopOrder >= _selectedEndStop!.stopOrder) {
      _showError('Destination cannot be before Pickup point');
      return;
    }

    try {
      setState(() { _isLoading = true; });

      final ticket = Ticket(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        studentId: widget.studentId,
        routeId: _selectedRoute!.id,
        busId: _selectedBus!.busNumber,
        startStopId: _selectedStartStop!.id,
        endStopId: _selectedEndStop!.id,
        fare: _calculateFare(),
        purchaseTime: DateTime.now(),
        isUsed: false,
      );

      final createdTicket = await SupabaseService().createTicket(ticket);

      if (createdTicket != null && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Ticket Booked Successfully!'),
              backgroundColor: Colors.green
          ),
        );
      }
    } catch (e) {
      _showError('Booking failed: $e');
      setState(() { _isLoading = false; });
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book Ticket'), backgroundColor: Colors.green),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. SELECT ROUTE
            _buildDropdownCard(
              title: "1. Select Route",
              child: DropdownButton<BusRoute>(
                isExpanded: true,
                hint: const Text("Choose a Route"),
                value: _selectedRoute,
                // Ensure unique IDs in dropdown to prevent crashes
                items: _routes.toSet().map((r) => DropdownMenuItem(
                    value: r,
                    child: Text(r.name)
                )).toList(),
                onChanged: _onRouteChanged,
              ),
            ),
            const SizedBox(height: 16),

            // 2. SELECT BUS (Always visible if data loaded)
            _buildDropdownCard(
              title: "2. Select Bus",
              child: DropdownButton<Bus>(
                isExpanded: true,
                hint: const Text("Choose a Bus"),
                value: _selectedBus,
                items: _activeBuses.map((b) => DropdownMenuItem(
                  value: b,
                  child: Text("Bus ${b.busNumber} ${b.licensePlate != null ? '(${b.licensePlate})' : ''}"),
                )).toList(),
                onChanged: (val) => setState(() => _selectedBus = val),
              ),
            ),
            const SizedBox(height: 16),

            // 3. SELECT STOPS (Only visible if Route selected & Stops loaded)
            if (_selectedRoute != null) ...[
              if (_stops.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text("No stops available for this route.", style: TextStyle(color: Colors.red)),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdownCard(
                        title: "3. Pickup",
                        child: DropdownButton<BusStop>(
                          isExpanded: true,
                          hint: const Text("Start"),
                          value: _selectedStartStop,
                          items: _stops.map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.name, overflow: TextOverflow.ellipsis)
                          )).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedStartStop = val;
                              // Auto-reset End Stop if it becomes invalid
                              if (_selectedEndStop != null && val != null &&
                                  _selectedEndStop!.stopOrder <= val.stopOrder) {
                                _selectedEndStop = null;
                              }
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDropdownCard(
                        title: "4. Drop-off",
                        child: DropdownButton<BusStop>(
                          isExpanded: true,
                          hint: const Text("End"),
                          value: _selectedEndStop,
                          // Filter: Only show stops AFTER the start stop
                          items: _stops.where((s) {
                            if (_selectedStartStop == null) return true;
                            return s.stopOrder > _selectedStartStop!.stopOrder;
                          }).map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.name, overflow: TextOverflow.ellipsis)
                          )).toList(),
                          onChanged: (val) => setState(() => _selectedEndStop = val),
                        ),
                      ),
                    ),
                  ],
                ),
            ],

            const SizedBox(height: 24),

            // 4. FARE & CONFIRM
            if (_selectedStartStop != null && _selectedEndStop != null)
              Card(
                color: Colors.green[50],
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text(
                        "Est. Fare",
                        style: TextStyle(color: Colors.green[800], fontSize: 16),
                      ),
                      Text(
                        "৳${_calculateFare().toStringAsFixed(0)}",
                        style: TextStyle(color: Colors.green[900], fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _bookTicket,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white
                          ),
                          child: const Text("CONFIRM BOOKING", style: TextStyle(fontSize: 18)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownCard({required String title, required Widget child}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}