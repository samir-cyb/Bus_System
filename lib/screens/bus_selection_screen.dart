import 'package:flutter/material.dart';
import 'package:ulab_bus/core/logger.dart';
import 'package:ulab_bus/core/models.dart';
import 'package:ulab_bus/screens/driver_dashboard.dart';
import 'package:ulab_bus/services/supabase_service.dart';

class BusSelectionScreen extends StatefulWidget {
  final String driverId;
  final String driverName;

  const BusSelectionScreen({
    super.key,
    required this.driverId,
    required this.driverName,
  });

  @override
  State<BusSelectionScreen> createState() => _BusSelectionScreenState();
}

class _BusSelectionScreenState extends State<BusSelectionScreen> {
  List<Bus> _availableBuses = [];
  bool _isLoading = true;
  String? _selectedBusId;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadAvailableBuses();
  }

  Future<void> _loadAvailableBuses() async {
    try {
      final buses = await SupabaseService().getAvailableBuses();
      setState(() {
        _availableBuses = buses;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('Failed to load buses', tag: 'BUS_SELECTION', error: e);
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load available buses. Please try again.';
      });
    }
  }

  Future<void> _assignBus() async {
    if (_selectedBusId == null) {
      _showError('Please select a bus');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final success = await SupabaseService().assignBusToDriver(widget.driverId, _selectedBusId!);

      if (!success) {
        _showError('Failed to assign bus. Please try again.');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      AppLogger.success('Bus assigned to driver: ${widget.driverId}', tag: 'BUS_SELECTION');

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DriverDashboard(
              driverId: widget.driverId,
              driverName: widget.driverName,
              busNumber: _selectedBusId!,
            ),
          ),
        );
      }
    } catch (e) {
      _showError('Failed to assign bus: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    AppLogger.error('Bus selection error: $message', tag: 'BUS_SELECTION');
    setState(() {
      _errorMessage = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
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
        title: const Text('Select Your Bus'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${widget.driverName}!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please select the bus you will be driving:',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // Error Message
            if (_errorMessage.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red[800]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage,
                        style: TextStyle(color: Colors.red[800]),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.red[800]),
                      onPressed: _clearError,
                    ),
                  ],
                ),
              ),

            if (_availableBuses.isEmpty)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions_bus, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No available buses at the moment',
                        style: TextStyle(color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Please contact administration',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _availableBuses.length,
                  itemBuilder: (context, index) {
                    final bus = _availableBuses[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: _selectedBusId == bus.busNumber
                          ? Colors.green[50]
                          : null,
                      child: ListTile(
                        leading: const Icon(Icons.directions_bus, size: 40),
                        title: Text(
                          'Bus ${bus.busNumber}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (bus.licensePlate != null)
                              Text('License: ${bus.licensePlate}'),
                            if (bus.capacity != null)
                              Text('Capacity: ${bus.capacity} seats'),
                            Text(
                              bus.currentDriverId == null
                                  ? 'Available'
                                  : 'Currently assigned to another driver',
                              style: TextStyle(
                                color: bus.currentDriverId == null
                                    ? Colors.green
                                    : Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        trailing: _selectedBusId == bus.busNumber
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedBusId = bus.busNumber;
                          });
                        },
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _selectedBusId != null ? _assignBus : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'CONFIRM BUS SELECTION',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}