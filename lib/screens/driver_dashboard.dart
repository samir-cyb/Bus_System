import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ulab_bus/core/logger.dart';
import 'package:ulab_bus/core/models.dart';
import 'package:ulab_bus/services/location_service.dart';
import 'package:intl/intl.dart';

class DriverDashboard extends StatefulWidget {
  final String driverId;
  final String driverName;
  final String busNumber;

  const DriverDashboard({
    super.key,
    required this.driverId,
    required this.driverName,
    required this.busNumber,
  });

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  int _currentIndex = 0;
  bool _isTripActive = false;
  String _lastLocationUpdate = "Not started";

  // Supabase client for direct database interactions (Tickets/Alerts)
  final _supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bus ${widget.busNumber} Dashboard'),
        backgroundColor: _isTripActive ? Colors.green : Colors.blueGrey,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _getCurrentScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed, // Needed for 4 items
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_bus),
            label: 'Trip',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Tickets',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_active),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        selectedItemColor: _isTripActive ? Colors.green : Colors.blueGrey,
        unselectedItemColor: Colors.grey,
      ),
    );
  }

  Widget _getCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return _buildTripScreen();
      case 1:
        return _buildTicketScreen();
      case 2:
        return _buildAlertScreen();
      case 3:
        return _buildProfileScreen();
      default:
        return _buildTripScreen();
    }
  }

  // ==========================================
  // TAB 1: TRIP & GPS (Replaces Map)
  // ==========================================
  Widget _buildTripScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isTripActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              border: Border.all(
                color: _isTripActive ? Colors.green : Colors.grey,
                width: 4,
              ),
            ),
            child: IconButton(
              iconSize: 80,
              icon: Icon(
                _isTripActive ? Icons.stop_circle : Icons.play_circle_fill,
                color: _isTripActive ? Colors.green : Colors.blueGrey,
              ),
              onPressed: _toggleTrip,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _isTripActive ? 'Trip in Progress' : 'Start Trip',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _isTripActive ? Colors.green : Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _isTripActive ? 'Broadcasting Location Live' : 'GPS is Off',
            style: const TextStyle(fontSize: 16),
          ),
          if (_isTripActive) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time, size: 16),
                  const SizedBox(width: 8),
                  Text("Last Ping: $_lastLocationUpdate"),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  void _toggleTrip() async {
    if (_isTripActive) {
      // STOP TRIP
      LocationService().stopLocationTracking();
      setState(() {
        _isTripActive = false;
        _lastLocationUpdate = "Ended";
      });
      AppLogger.info("Trip Ended", tag: "DRIVER");
    } else {
      // START TRIP
      // Initialize service first
      bool initialized = await LocationService().initializeLocationService();
      if (!initialized) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied. Cannot start trip.')),
        );
        return;
      }

      LocationService().startLocationTracking(
        widget.busNumber, // Assuming Bus Number is the ID, otherwise map this
        widget.driverId,
            (BusLocation loc) {
          // This callback runs every time the GPS updates
          if (mounted) {
            setState(() {
              _lastLocationUpdate = DateFormat('h:mm:ss a').format(DateTime.now());
            });
          }
        },
      );

      setState(() {
        _isTripActive = true;
        _lastLocationUpdate = "Starting...";
      });
      AppLogger.info("Trip Started", tag: "DRIVER");
    }
  }

  // ==========================================
  // TAB 2: TICKET VALIDATOR (Updated with Name)
  // ==========================================
  Widget _buildTicketScreen() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "Pending Tickets for Bus ${widget.busNumber}",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _supabase
                .from('tickets')
                .stream(primaryKey: ['id'])
                .order('purchase_time', ascending: true),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              // Filter: Only shows tickets for THIS bus that are NOT used
              final allTickets = snapshot.data!;
              final myTickets = allTickets.where((ticket) {
                return ticket['bus_id'] == widget.busNumber &&
                    ticket['is_used'] == false;
              }).toList();

              if (myTickets.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.airplane_ticket_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("No pending tickets"),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: myTickets.length,
                itemBuilder: (context, index) {
                  final ticket = myTickets[index];
                  // We use a custom widget here to handle fetching the name
                  return TicketListItem(
                    ticket: ticket,
                    onValidate: () => _validateTicket(ticket['id']),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _validateTicket(String ticketId) async {
    try {
      await _supabase.from('tickets').update({
        'is_used': true,
        'usage_time': DateTime.now().toIso8601String(),
      }).eq('id', ticketId);

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket Validated Successfully')),
        );
      }
    } catch (e) {
      AppLogger.error("Failed to validate ticket", tag: "DRIVER", error: e);
    }
  }

  // ==========================================
  // TAB 3: ALERTS (Traffic/Breakdown)
  // ==========================================
  Widget _buildAlertScreen() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Notify Students",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          _buildAlertButton(
            "Heavy Traffic",
            Icons.traffic,
            Colors.orange,
            "Bus ${widget.busNumber} is stuck in heavy traffic.",
          ),
          const SizedBox(height: 20),
          _buildAlertButton(
            "Bus Breakdown",
            Icons.build_circle,
            Colors.red,
            "Bus ${widget.busNumber} has a mechanical issue.",
          ),
          const SizedBox(height: 20),
          _buildAlertButton(
            "Slight Delay",
            Icons.access_time,
            Colors.blue,
            "Bus ${widget.busNumber} is running 15 mins late.",
          ),
        ],
      ),
    );
  }

  Widget _buildAlertButton(String label, IconData icon, Color color, String message) {
    return SizedBox(
      height: 80,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: Icon(icon, size: 32),
        label: Text(label, style: const TextStyle(fontSize: 20)),
        onPressed: () => _sendAlert(label, message),
      ),
    );
  }

  Future<void> _sendAlert(String type, String message) async {
    try {
      final alert = Alert(
        id: DateTime.now().millisecondsSinceEpoch.toString(), // Simple ID gen
        alertType: type,
        message: message,
        busId: widget.busNumber,
        driverId: widget.driverId,
        timestamp: DateTime.now(),
      );

      await _supabase.from('alerts').insert(alert.toMap());

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Alert "$type" Sent!')),
        );
      }
    } catch (e) {
      AppLogger.error("Failed to send alert", tag: "DRIVER", error: e);
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send alert: $e')),
        );
      }
    }
  }

  // ==========================================
  // TAB 4: PROFILE
  // ==========================================
  Widget _buildProfileScreen() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.blueGrey,
                      borderRadius: BorderRadius.circular(35),
                    ),
                    child: const Icon(Icons.person, size: 40, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.driverName,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 5),
                        Text('ID: ${widget.driverId}', style: const TextStyle(color: Colors.grey)),
                        Text('Assigned Bus: ${widget.busNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }



  void _logout() {
    // If trip is active, stop it before logging out
    if (_isTripActive) {
      LocationService().stopLocationTracking();
    }
    AppLogger.info('Driver logging out: ${widget.driverId}', tag: 'AUTH');
    Navigator.pushReplacementNamed(context, '/');
  }
}

// Helper Widget to fetch and display Student Name
class TicketListItem extends StatefulWidget {
  final Map<String, dynamic> ticket;
  final VoidCallback onValidate;

  const TicketListItem({
    super.key,
    required this.ticket,
    required this.onValidate,
  });

  @override
  State<TicketListItem> createState() => _TicketListItemState();
}

class _TicketListItemState extends State<TicketListItem> {
  String _studentName = 'Loading Name...';

  @override
  void initState() {
    super.initState();
    _fetchStudentName();
  }

  Future<void> _fetchStudentName() async {
    final studentId = widget.ticket['student_id'];

    try {
      // FIX: Use Supabase.instance directly instead of LocationService
      final response = await Supabase.instance.client
          .from('users')
          .select('name')
          .eq('user_id', studentId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          if (response != null && response['name'] != null) {
            _studentName = response['name'];
          } else {
            _studentName = 'Unknown Student';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _studentName = 'Error loading name';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue[100],
          child: Text(
            _studentName.isNotEmpty ? _studentName[0].toUpperCase() : "?",
            style: TextStyle(color: Colors.blue[800]),
          ),
        ),
        title: Text(
          _studentName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("ID: ${widget.ticket['student_id']}"),
            Text("Fare: ${widget.ticket['fare']} BDT",
                style: TextStyle(color: Colors.green[700])),
          ],
        ),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          onPressed: widget.onValidate,
          child: const Text("Activate"),
        ),
      ),
    );
  }
}