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
  final _supabase = Supabase.instance.client;

  // Search Controller
  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bus ${widget.busNumber}'),
        backgroundColor: _isTripActive ? Colors.green : Colors.blueGrey,
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _logout)],
      ),
      body: _getCurrentScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.directions_bus), label: 'Trip'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'Tickets'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_active), label: 'Alerts'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        selectedItemColor: _isTripActive ? Colors.green : Colors.blueGrey,
      ),
    );
  }

  Widget _getCurrentScreen() {
    switch (_currentIndex) {
      case 0: return _buildTripScreen();
      case 1: return _buildTicketScreen();
      case 2: return _buildAlertScreen();
      case 3: return _buildProfileScreen();
      default: return _buildTripScreen();
    }
  }

  // --- TAB 1: TRIP ---
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
              border: Border.all(color: _isTripActive ? Colors.green : Colors.grey, width: 4),
            ),
            child: IconButton(
              iconSize: 80,
              icon: Icon(_isTripActive ? Icons.stop_circle : Icons.play_circle_fill, color: _isTripActive ? Colors.green : Colors.blueGrey),
              onPressed: _toggleTrip,
            ),
          ),
          const SizedBox(height: 20),
          Text(_isTripActive ? 'Trip Active' : 'Start Trip', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          if (_isTripActive) Text("Last Ping: $_lastLocationUpdate"),
        ],
      ),
    );
  }

  void _toggleTrip() async {
    if (_isTripActive) {
      LocationService().stopLocationTracking();
      setState(() { _isTripActive = false; _lastLocationUpdate = "Ended"; });
    } else {
      bool initialized = await LocationService().initializeLocationService();
      if (!initialized) return;
      LocationService().startLocationTracking(widget.busNumber, widget.driverId, (loc) {
        if(mounted) setState(() => _lastLocationUpdate = DateFormat('h:mm:ss a').format(DateTime.now()));
      });
      setState(() { _isTripActive = true; _lastLocationUpdate = "Starting..."; });
    }
  }

  // --- TAB 2: TICKETS (WITH SEARCH) ---
  Widget _buildTicketScreen() {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Search Student ID...",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            onChanged: (val) => setState(() => _searchText = val),
          ),
        ),

        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _supabase.from('tickets').stream(primaryKey: ['id']).order('purchase_time', ascending: true),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              final allTickets = snapshot.data!;

              // Filter: Bus Number + Active + Search Text
              final myTickets = allTickets.where((ticket) {
                bool matchesBus = ticket['bus_id'] == widget.busNumber;
                bool isActive = ticket['is_used'] == false;
                bool matchesSearch = _searchText.isEmpty ||
                    ticket['student_id'].toString().toLowerCase().contains(_searchText.toLowerCase());
                return matchesBus && isActive && matchesSearch;
              }).toList();

              if (myTickets.isEmpty) {
                return const Center(child: Text("No tickets found matching search."));
              }

              return ListView.builder(
                itemCount: myTickets.length,
                itemBuilder: (context, index) {
                  final ticket = myTickets[index];
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
    await _supabase.from('tickets').update({'is_used': true, 'usage_time': DateTime.now().toIso8601String()}).eq('id', ticketId);
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket Validated!')));
  }

  // --- TAB 3: ALERTS ---
  Widget _buildAlertScreen() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text("Send Alerts", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildAlertBtn("Heavy Traffic", Icons.traffic, Colors.orange),
          const SizedBox(height: 10),
          _buildAlertBtn("Bus Breakdown", Icons.build, Colors.red),
          const SizedBox(height: 10),
          _buildAlertBtn("Slight Delay", Icons.timer, Colors.blue),
        ],
      ),
    );
  }

  Widget _buildAlertBtn(String text, IconData icon, Color color) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        icon: Icon(icon), label: Text(text),
        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
        onPressed: () async {
          await _supabase.from('alerts').insert({
            'id': DateTime.now().millisecondsSinceEpoch.toString(), // <--- ADD THIS LINE
            'alert_type': text,
            'message': 'Driver reported $text',
            'bus_id': widget.busNumber,
            'driver_id': widget.driverId,
            'timestamp': DateTime.now().toIso8601String()
          });
          if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$text Sent!")));
        },
      ),
    );
  }

  // --- TAB 4: PROFILE ---
  Widget _buildProfileScreen() {
    return Center(child: Text("Driver: ${widget.driverName}\nBus: ${widget.busNumber}"));
  }

  void _logout() {
    if (_isTripActive) LocationService().stopLocationTracking();
    Navigator.pushReplacementNamed(context, '/');
  }
}

class TicketListItem extends StatefulWidget {
  final Map<String, dynamic> ticket;
  final VoidCallback onValidate;
  const TicketListItem({super.key, required this.ticket, required this.onValidate});
  @override
  State<TicketListItem> createState() => _TicketListItemState();
}

class _TicketListItemState extends State<TicketListItem> {
  String _name = 'Loading...';
  @override
  void initState() { super.initState(); _fetchName(); }

  void _fetchName() async {
    final res = await Supabase.instance.client.from('users').select('name').eq('user_id', widget.ticket['student_id']).maybeSingle();
    if(mounted) setState(() => _name = res?['name'] ?? 'Unknown');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(_name.isNotEmpty ? _name[0] : "?")),
        title: Text(_name),
        subtitle: Text("ID: ${widget.ticket['student_id']}\nFare: ${widget.ticket['fare']} BDT"),
        isThreeLine: true,
        trailing: ElevatedButton(
          onPressed: widget.onValidate,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          child: const Text("Activate"),
        ),
      ),
    );
  }
}