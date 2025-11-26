import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ulab_bus/core/logger.dart';
import 'package:ulab_bus/screens/ticket_booking_screen.dart';
import 'package:ulab_bus/screens/ticket_history_screen.dart';
import 'package:ulab_bus/widgets/bus_map.dart';
import 'package:ulab_bus/services/location_service.dart';

import 'debug_screen.dart';

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
    if(mounted) setState(() => _locationEnabled = enabled);
  }

  void _logout() {
    AppLogger.info('Student logging out: ${widget.studentId}', tag: 'AUTH');
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  // Add this method to fix the error
  void _refreshTickets() {
    // Since we use StreamBuilder, data updates automatically.
    // We just call setState to ensure the UI catches up if needed.
    if (mounted) {
      setState(() {});
    }
  }

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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, ${widget.studentName}!',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      const SizedBox(height: 8),
                      const Text('ULAB Bus System', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.person, color: Colors.white)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Text('Quick Actions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                          builder: (context) => TicketBookingScreen( // <--- Change this back from DebugScreen
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
              Expanded(
                child: Card(
                  child: InkWell(
                    onTap: () => setState(() => _currentIndex = 1),
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
          const Text('Recent Tickets', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // REAL-TIME STREAM FOR RECENT TICKETS
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _supabase
                .from('tickets')
                .stream(primaryKey: ['id'])
                .eq('student_id', widget.studentId)
                .order('purchase_time', ascending: false)
                .limit(3),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Text('Error: ${snapshot.error}');
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              final tickets = snapshot.data!;
              // Filter out hidden tickets
              final visibleTickets = tickets.where((t) => t['is_hidden_by_student'] != true).toList();

              if (visibleTickets.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(child: Text("No recent tickets")),
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
                  MaterialPageRoute(builder: (context) => TicketHistoryScreen(studentId: widget.studentId)),
                );
              },
              child: const Text('VIEW ALL TICKETS'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapTab() {
    return BusMap(
      userType: 'student',
      userId: widget.studentId,
      onBookTicket: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => TicketBookingScreen(
              studentId: widget.studentId, studentName: widget.studentName)
          ),
        );
      },
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
          // LOGOUT BUTTON
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
          const Center(child: Text("Profile Tab Placeholder")), // You can reuse your profile tab code here
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Live Map'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}