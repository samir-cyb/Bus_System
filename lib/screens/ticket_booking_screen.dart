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
  List<BusRoute> _routes = [];
  List<BusStop> _stops = [];
  List<Bus> _activeBuses = []; // New list for buses

  BusRoute? _selectedRoute;
  BusStop? _selectedStartStop;
  BusStop? _selectedEndStop;
  Bus? _selectedBus; // New selection

  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    try {
      final routes = await SupabaseService().getRoutes();
      // Also load active buses
      final buses = await SupabaseService().getAvailableBuses();

      setState(() {
        _routes = routes;
        _activeBuses = buses;
        _isLoading = false;
      });
    } catch (e) {
      _showError('Failed to load data. Check connection.');
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _loadStopsForRoute(String routeId) async {
    try {
      setState(() { _isLoading = true; });
      final stops = await SupabaseService().getStopsForRoute(routeId);
      setState(() {
        _stops = stops;
        _selectedStartStop = null;
        _selectedEndStop = null;
        _isLoading = false;
      });
    } catch (e) {
      _showError('Failed to load stops.');
      setState(() { _isLoading = false; });
    }
  }

  double _calculateFare() {
    if (_selectedStartStop == null || _selectedEndStop == null) return 0.0;
    final startFare = _selectedStartStop!.fareFromStart;
    final endFare = _selectedEndStop!.fareFromStart;
    return (endFare - startFare).abs();
  }

  Future<void> _bookTicket() async {
    if (_selectedRoute == null || _selectedStartStop == null || _selectedEndStop == null || _selectedBus == null) {
      _showError('Please complete all selections');
      return;
    }

    if (_selectedStartStop!.stopOrder >= _selectedEndStop!.stopOrder) {
      _showError('End stop must be after start stop');
      return;
    }

    try {
      setState(() { _isLoading = true; });

      final ticket = Ticket(
        id: DateTime.now().millisecondsSinceEpoch.toString(), // Simple ID
        studentId: widget.studentId,
        routeId: _selectedRoute!.id,
        busId: _selectedBus!.busNumber, // This is CRUCIAL for the driver to see it
        startStopId: _selectedStartStop!.id,
        endStopId: _selectedEndStop!.id,
        fare: _calculateFare(),
        purchaseTime: DateTime.now(),
        isUsed: false,
      );

      final createdTicket = await SupabaseService().createTicket(ticket);

      if (createdTicket != null) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ticket Booked Successfully!'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      _showError('Booking failed: $e');
      setState(() { _isLoading = false; });
    }
  }

  void _showError(String message) {
    if(mounted) {
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
              title: "Select Route",
              child: DropdownButton<BusRoute>(
                isExpanded: true,
                hint: const Text("Choose a Route"),
                value: _selectedRoute,
                items: _routes.map((r) => DropdownMenuItem(value: r, child: Text(r.name))).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedRoute = val;
                    if (val != null) _loadStopsForRoute(val.id);
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            // 2. SELECT BUS (New Feature)
            if (_selectedRoute != null)
              _buildDropdownCard(
                title: "Select Bus",
                child: DropdownButton<Bus>(
                  isExpanded: true,
                  hint: const Text("Choose a Bus"),
                  value: _selectedBus,
                  items: _activeBuses.map((b) => DropdownMenuItem(
                    value: b,
                    child: Text("Bus ${b.busNumber} (${b.licensePlate ?? 'No Plate'})"),
                  )).toList(),
                  onChanged: (val) {
                    setState(() { _selectedBus = val; });
                  },
                ),
              ),
            const SizedBox(height: 16),

            // 3. SELECT STOPS
            if (_selectedRoute != null) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildDropdownCard(
                      title: "From",
                      child: DropdownButton<BusStop>(
                        isExpanded: true,
                        hint: const Text("Start"),
                        value: _selectedStartStop,
                        items: _stops.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                        onChanged: (val) => setState(() => _selectedStartStop = val),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDropdownCard(
                      title: "To",
                      child: DropdownButton<BusStop>(
                        isExpanded: true,
                        hint: const Text("End"),
                        value: _selectedEndStop,
                        items: _stops.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                        onChanged: (val) => setState(() => _selectedEndStop = val),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),

            // 4. FARE & ACTION
            if (_selectedStartStop != null && _selectedEndStop != null)
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text(
                        "Total Fare",
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
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: const Text("CONFIRM BOOKING", style: TextStyle(color: Colors.white, fontSize: 18)),
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