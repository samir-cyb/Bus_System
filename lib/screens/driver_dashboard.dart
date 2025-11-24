import 'package:flutter/material.dart';
import 'package:ulab_bus/core/logger.dart';
import 'package:ulab_bus/widgets/bus_map.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bus ${widget.busNumber}'),
        backgroundColor: Colors.blue,
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
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Live Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.route),
            label: 'Route',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
      ),
    );
  }

  Widget _getCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return BusMap(
          userType: 'driver',
          userId: widget.driverId,
          busNumber: widget.busNumber,
          isTripActive: _isTripActive,
          onTripStatusChanged: (isActive) {
            setState(() {
              _isTripActive = isActive;
            });
          },
        );
      case 1:
        return _buildRouteScreen();
      case 2:
        return _buildProfileScreen();
      default:
        return BusMap(
          userType: 'driver',
          userId: widget.driverId,
          busNumber: widget.busNumber,
          isTripActive: _isTripActive,
          onTripStatusChanged: (isActive) {
            setState(() {
              _isTripActive = isActive;
            });
          },
        );
    }
  }

  Widget _buildRouteScreen() {
    return const Center(
      child: Text(
        'Route Management Screen - Implement route details here',
        style: TextStyle(fontSize: 18),
      ),
    );
  }

  Widget _buildProfileScreen() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.driverName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('Driver ID: ${widget.driverId}'),
                        Text('Bus: ${widget.busNumber}'),
                        Text(
                          'ULAB Bus Driver',
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Add more driver-specific information here
        ],
      ),
    );
  }

  void _logout() {
    AppLogger.info('Driver logging out: ${widget.driverId}', tag: 'AUTH');
    Navigator.pushReplacementNamed(context, '/');
  }
}