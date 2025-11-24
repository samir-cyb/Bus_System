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
  BusRoute? _selectedRoute;
  BusStop? _selectedStartStop;
  BusStop? _selectedEndStop;
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
      setState(() {
        _routes = routes;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('Failed to load routes', tag: 'TICKET_BOOKING', error: e);
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load routes. Please check your connection.';
      });
      _showError('Failed to load routes');
    }
  }

  Future<void> _loadStopsForRoute(String routeId) async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final stops = await SupabaseService().getStopsForRoute(routeId);
      setState(() {
        _stops = stops;
        _selectedStartStop = null;
        _selectedEndStop = null;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('Failed to load stops', tag: 'TICKET_BOOKING', error: e);
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load stops for selected route.';
      });
      _showError('Failed to load stops for selected route');
    }
  }

  double _calculateFare() {
    if (_selectedStartStop == null || _selectedEndStop == null) return 0.0;

    final startFare = _selectedStartStop!.fareFromStart;
    final endFare = _selectedEndStop!.fareFromStart;

    return (endFare - startFare).abs();
  }

  Future<void> _bookTicket() async {
    if (_selectedRoute == null || _selectedStartStop == null || _selectedEndStop == null) {
      _showError('Please select route, start stop, and end stop');
      return;
    }

    if (_selectedStartStop!.stopOrder >= _selectedEndStop!.stopOrder) {
      _showError('End stop must be after start stop');
      return;
    }

    final fare = _calculateFare();

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final ticket = Ticket(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        studentId: widget.studentId,
        routeId: _selectedRoute!.id,
        busId: _selectedRoute!.busId ?? '',
        startStopId: _selectedStartStop!.id,
        endStopId: _selectedEndStop!.id,
        fare: fare,
        purchaseTime: DateTime.now(),
        isUsed: false,
      );

      final createdTicket = await SupabaseService().createTicket(ticket);

      if (createdTicket == null) {
        throw Exception('Failed to create ticket');
      }

      AppLogger.success('Ticket booked for student: ${widget.studentId}', tag: 'TICKET_BOOKING');

      if (mounted) {
        Navigator.pop(context);
        _showSuccess('Ticket booked successfully! Fare: ৳${fare.toStringAsFixed(2)}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to book ticket. Please try again.';
      });
      _showError('Failed to book ticket: $e');
    }
  }

  void _showError(String message) {
    AppLogger.error('Ticket booking error: $message', tag: 'TICKET_BOOKING');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _clearError() {
    setState(() {
      _errorMessage = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Ticket'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Error Message
          if (_errorMessage.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red[800], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage,
                      style: TextStyle(
                        color: Colors.red[800],
                        fontSize: 14,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.red[800], size: 20),
                    onPressed: _clearError,
                  ),
                ],
              ),
            ),

          // Main Content - Scrollable
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Route Selection
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Select Route',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButton<BusRoute>(
                            value: _selectedRoute,
                            isExpanded: true,
                            hint: const Text('Choose a route'),
                            items: _routes.map((route) {
                              return DropdownMenuItem<BusRoute>(
                                value: route,
                                child: Text(route.name),
                              );
                            }).toList(),
                            onChanged: (BusRoute? newValue) {
                              setState(() {
                                _selectedRoute = newValue;
                                _errorMessage = '';
                                if (newValue != null) {
                                  _loadStopsForRoute(newValue.id);
                                } else {
                                  _stops.clear();
                                  _selectedStartStop = null;
                                  _selectedEndStop = null;
                                }
                              });
                            },
                          ),
                          if (_selectedRoute != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _selectedRoute!.description,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Start Stop Selection - Only show if route is selected
                  if (_selectedRoute != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Start Stop',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButton<BusStop>(
                              value: _selectedStartStop,
                              isExpanded: true,
                              hint: const Text('Choose start stop'),
                              items: _stops.map((stop) {
                                return DropdownMenuItem<BusStop>(
                                  value: stop,
                                  child: Text('${stop.stopOrder}. ${stop.name}'),
                                );
                              }).toList(),
                              onChanged: (BusStop? newValue) {
                                setState(() {
                                  _selectedStartStop = newValue;
                                  _errorMessage = '';
                                  // Reset end stop if it's before start stop
                                  if (_selectedEndStop != null &&
                                      newValue != null &&
                                      _selectedEndStop!.stopOrder <= newValue.stopOrder) {
                                    _selectedEndStop = null;
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // End Stop Selection - Only show if route and start stop are selected
                  if (_selectedRoute != null && _selectedStartStop != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'End Stop',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButton<BusStop>(
                              value: _selectedEndStop,
                              isExpanded: true,
                              hint: const Text('Choose end stop'),
                              items: _stops
                                  .where((stop) => stop.stopOrder > _selectedStartStop!.stopOrder)
                                  .map((stop) {
                                return DropdownMenuItem<BusStop>(
                                  value: stop,
                                  child: Text('${stop.stopOrder}. ${stop.name}'),
                                );
                              }).toList(),
                              onChanged: (BusStop? newValue) {
                                setState(() {
                                  _selectedEndStop = newValue;
                                  _errorMessage = '';
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Fare Calculation - Only show if both stops are selected
                  if (_selectedStartStop != null && _selectedEndStop != null)
                    Card(
                      color: Colors.green[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Fare:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '৳${_calculateFare().toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Route Information - Only show if route is selected
                  if (_selectedRoute != null) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Route Information:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedRoute!.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedRoute!.description,
                              style: const TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Stops available: ${_stops.length}',
                              style: const TextStyle(
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Add some extra space at the bottom for better scrolling
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // Fixed Book Ticket Button at bottom
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _selectedRoute != null &&
                    _selectedStartStop != null &&
                    _selectedEndStop != null
                    ? _bookTicket
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'BOOK TICKET',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}