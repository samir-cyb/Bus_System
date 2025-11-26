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
          GestureDetector(
            onTap: _toggleTrip,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isTripActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                  border: Border.all(
                      color: _isTripActive ? Colors.green : Colors.grey,
                      width: 6
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isTripActive ? Colors.green : Colors.grey).withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    )
                  ]
              ),
              child: Icon(
                _isTripActive ? Icons.stop_rounded : Icons.play_arrow_rounded,
                size: 80,
                color: _isTripActive ? Colors.green : Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 30),
          Text(
            _isTripActive ? 'TRIP ACTIVE' : 'START TRIP',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _isTripActive ? Colors.green : Colors.grey,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _isTripActive ? "Broadcasting Location..." : "Location Hidden",
            style: TextStyle(color: Colors.grey[600]),
          ),
          if (_isTripActive)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Chip(
                avatar: const Icon(Icons.access_time, size: 16),
                label: Text("Ping: $_lastLocationUpdate"),
              ),
            ),
        ],
      ),
    );
  }

  void _toggleTrip() async {
    if (_isTripActive) {
      LocationService().stopLocationTracking(); // This now deletes from DB
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

  // --- TAB 2: TICKETS ---
  Widget _buildTicketScreen() {
    return Column(
      children: [
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
              final myTickets = allTickets.where((ticket) {
                bool matchesBus = ticket['bus_id'] == widget.busNumber;
                bool isActive = ticket['is_used'] == false;
                bool matchesSearch = _searchText.isEmpty || ticket['student_id'].toString().toLowerCase().contains(_searchText.toLowerCase());
                return matchesBus && isActive && matchesSearch;
              }).toList();

              if (myTickets.isEmpty) return const Center(child: Text("No active tickets."));

              return ListView.builder(
                itemCount: myTickets.length,
                itemBuilder: (context, index) => TicketListItem(
                  ticket: myTickets[index],
                  onValidate: () => _validateTicket(myTickets[index]['id']),
                ),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAlertBtn("Heavy Traffic", Icons.traffic, Colors.orange),
          const SizedBox(height: 16),
          _buildAlertBtn("Bus Breakdown", Icons.build, Colors.red),
          const SizedBox(height: 16),
          _buildAlertBtn("Slight Delay", Icons.timer, Colors.blue),
        ],
      ),
    );
  }

  Widget _buildAlertBtn(String text, IconData icon, Color color) {
    return SizedBox(
      width: double.infinity,
      height: 70,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 30),
        label: Text(text, style: const TextStyle(fontSize: 18)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 4,
        ),
        onPressed: () async {
          await _supabase.from('alerts').insert({
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
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

  // --- TAB 4: PROFILE (NEW) ---
  Widget _buildProfileScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.blueGrey,
            child: Text(
              widget.driverName.isNotEmpty ? widget.driverName[0].toUpperCase() : "D",
              style: const TextStyle(fontSize: 50, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.driverName,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(20)),
            child: Text("Driver", style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 40),

          // Details Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge, color: Colors.blue),
                  title: const Text("Driver ID"),
                  subtitle: Text(widget.driverId),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.directions_bus, color: Colors.orange),
                  title: const Text("Assigned Bus"),
                  subtitle: Text(widget.busNumber),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.email, color: Colors.purple),
                  title: const Text("Status"),
                  subtitle: Text(_isTripActive ? "Currently Driving" : "Idle"),
                  trailing: Icon(
                      Icons.circle,
                      color: _isTripActive ? Colors.green : Colors.grey,
                      size: 14
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text("LOGOUT"),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
              onPressed: _logout,
            ),
          ),
        ],
      ),
    );
  }

  void _logout() {
    if (_isTripActive) {
      LocationService().stopLocationTracking(); // Cleans up ghost bus
    }
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(child: Text(_name.isNotEmpty ? _name[0] : "?")),
        title: Text(_name, style: const TextStyle(fontWeight: FontWeight.bold)),
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