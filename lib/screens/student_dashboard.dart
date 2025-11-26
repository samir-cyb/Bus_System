import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ulab_bus/core/logger.dart';
import 'package:ulab_bus/screens/ticket_booking_screen.dart';
import 'package:ulab_bus/screens/ticket_history_screen.dart';
import 'package:ulab_bus/widgets/bus_map.dart';
import 'package:ulab_bus/services/location_service.dart';

class StudentDashboard extends StatefulWidget {
  final String studentId;
  final String studentName;

  const StudentDashboard({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _currentIndex = 0;
  bool _locationEnabled = false;
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  Future<void> _initializeDashboard() async {
    final locationService = LocationService();
    final enabled = await locationService.initializeLocationService();
    if (mounted) {
      setState(() {
        _locationEnabled = enabled;
      });
    }
  }

  void _logout() {
    AppLogger.info('Student logging out: ${widget.studentId}', tag: 'AUTH');
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  // Helper to refresh UI when returning from booking
  void _refreshTickets() {
    if (mounted) {
      setState(() {});
    }
  }

  // ==================================================
  // TAB 1: HOME
  // ==================================================
  Widget _buildHomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Card
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, ${widget.studentName}!',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'ULAB Bus System',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Card(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TicketBookingScreen(
                            studentId: widget.studentId,
                            studentName: widget.studentName,
                          ),
                        ),
                      ).then((_) => _refreshTickets());
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(Icons.confirmation_number, size: 40, color: Colors.green),
                          SizedBox(height: 8),
                          Text('Book Ticket', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Card(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _currentIndex = 1; // Switch to Map tab
                      });
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(Icons.map, size: 40, color: Colors.blue),
                          SizedBox(height: 8),
                          Text('Live Map', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Text(
            'Recent Tickets',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // REAL-TIME STREAM FOR RECENT TICKETS
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _supabase
                .from('tickets')
                .stream(primaryKey: ['id'])
                .eq('student_id', widget.studentId)
                .order('purchase_time', ascending: false)
                .limit(5), // Fetch slightly more to handle hidden ones
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final tickets = snapshot.data!;
              // Filter out tickets hidden by user
              final visibleTickets = tickets.where((t) => t['is_hidden_by_student'] != true).take(3).toList();

              if (visibleTickets.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.airplane_ticket_outlined, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text("No recent tickets", style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: visibleTickets.map((ticket) {
                  final isUsed = ticket['is_used'] as bool;
                  final fare = ticket['fare'];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Icon(
                        isUsed ? Icons.history : Icons.confirmation_number,
                        color: isUsed ? Colors.grey : Colors.green,
                      ),
                      title: Text('Bus ${ticket['bus_id']}'),
                      subtitle: Text('Fare: ৳$fare'),
                      trailing: Chip(
                        label: Text(isUsed ? 'USED' : 'ACTIVE'),
                        backgroundColor: isUsed ? Colors.grey[300] : Colors.green[100],
                        labelStyle: TextStyle(
                          color: isUsed ? Colors.grey[800] : Colors.green[900],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TicketHistoryScreen(studentId: widget.studentId),
                  ),
                );
              },
              child: const Text('VIEW ALL TICKETS'),
            ),
          ),
        ],
      ),
    );
  }

  // ==================================================
  // TAB 2: MAP
  // ==================================================
  Widget _buildMapTab() {
    return BusMap(
      userType: 'student',
      userId: widget.studentId,
      onBookTicket: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TicketBookingScreen(
              studentId: widget.studentId,
              studentName: widget.studentName,
            ),
          ),
        );
      },
    );
  }

  // ==================================================
  // TAB 3: PROFILE
  // ==================================================
  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.green[100],
            child: Text(
              widget.studentName.isNotEmpty ? widget.studentName[0].toUpperCase() : "S",
              style: const TextStyle(
                fontSize: 50,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.studentName,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "Student",
              style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold),
            ),
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
                  title: const Text("Student ID"),
                  subtitle: Text(widget.studentId),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.history, color: Colors.orange),
                  title: const Text("Ticket History"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TicketHistoryScreen(studentId: widget.studentId),
                      ),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.help, color: Colors.purple),
                  title: const Text("Help & Support"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Help"),
                        content: const Text("For support, contact the transport office at ULAB Campus A."),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))
                        ],
                      ),
                    );
                  },
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
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
              onPressed: _logout,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ULAB Bus System'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
            onPressed: _logout,
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(),
          _buildMapTab(),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Live Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}