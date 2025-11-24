import 'package:flutter/material.dart';
import 'package:ulab_bus/core/logger.dart';
import 'package:ulab_bus/screens/ticket_booking_screen.dart';
import 'package:ulab_bus/screens/ticket_history_screen.dart';
import 'package:ulab_bus/widgets/bus_map.dart';
import 'package:ulab_bus/services/supabase_service.dart';
import 'package:ulab_bus/services/location_service.dart';

import '../core/models.dart';

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
  List<Map<String, dynamic>> _recentTickets = [];
  bool _isLoading = true;
  bool _locationEnabled = false;

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  Future<void> _initializeDashboard() async {
    try {
      // Initialize location service
      final locationService = LocationService();
      _locationEnabled = await locationService.initializeLocationService();

      // Load recent tickets
      await _loadRecentTickets();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('Failed to initialize dashboard', tag: 'STUDENT_DASHBOARD', error: e);
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRecentTickets() async {
    try {
      final tickets = await SupabaseService().getStudentTickets(widget.studentId);
      setState(() {
        _recentTickets = tickets.take(3).map((ticket) {
          return {
            'ticket': ticket,
            'displayText': 'Bus ${ticket.busId} - ৳${ticket.fare.toStringAsFixed(2)}',
          };
        }).toList();
      });
    } catch (e) {
      AppLogger.error('Failed to load recent tickets', tag: 'STUDENT_DASHBOARD', error: e);
    }
  }

  void _refreshTickets() {
    _loadRecentTickets();
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, ${widget.studentName}!',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ULAB Bus System - Smart Campus Transportation',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Quick Actions
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
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
                          Text(
                            'Book Ticket',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
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
                          Text(
                            'Live Map',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Recent Tickets
          const Text(
            'Recent Tickets',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          if (_recentTickets.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Icon(Icons.confirmation_number, size: 50, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text(
                      'No tickets yet',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Book your first ticket to get started!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: _recentTickets.map((ticketData) {
                final ticket = ticketData['ticket'] as Ticket;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Icon(
                      ticket.isUsed ? Icons.history : Icons.confirmation_number,
                      color: ticket.isUsed ? Colors.grey : Colors.green,
                    ),
                    title: Text('Bus ${ticket.busId}'),
                    subtitle: Text('Fare: ৳${ticket.fare.toStringAsFixed(2)}'),
                    trailing: Chip(
                      label: Text(ticket.isUsed ? 'USED' : 'ACTIVE'),
                      backgroundColor: ticket.isUsed ? Colors.grey[300] : Colors.green[100],
                    ),
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TicketHistoryScreen(
                      studentId: widget.studentId,
                    ),
                  ),
                ).then((_) => _refreshTickets());
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
          MaterialPageRoute(
            builder: (context) => TicketBookingScreen(
              studentId: widget.studentId,
              studentName: widget.studentName,
            ),
          ),
        ).then((_) => _refreshTickets());
      },
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.green,
                    radius: 40,
                    child: Text(
                      widget.studentName[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.studentName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ID: ${widget.studentId}',
                    style: const TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Student',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.location_on, color: Colors.blue),
                  title: const Text('Location Services'),
                  subtitle: Text(_locationEnabled ? 'Enabled' : 'Disabled'),
                  trailing: Switch(
                    value: _locationEnabled,
                    onChanged: (value) async {
                      final locationService = LocationService();
                      final enabled = await locationService.initializeLocationService();
                      setState(() {
                        _locationEnabled = enabled;
                      });
                    },
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.history, color: Colors.orange),
                  title: const Text('Ticket History'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TicketHistoryScreen(
                          studentId: widget.studentId,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.help, color: Colors.purple),
                  title: const Text('Help & Support'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _showHelpDialog();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Book tickets from the "Book Ticket" section'),
            SizedBox(height: 8),
            Text('• View live bus locations on the map'),
            SizedBox(height: 8),
            Text('• Check your ticket history anytime'),
            SizedBox(height: 8),
            Text('• Enable location for better experience'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
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
            icon: const Icon(Icons.refresh),
            onPressed: _refreshTickets,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
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