import 'package:flutter/material.dart';
import 'package:ulab_bus/core/logger.dart';
import 'package:ulab_bus/core/models.dart';
import 'package:ulab_bus/screens/student_dashboard.dart';
import 'package:ulab_bus/screens/driver_dashboard.dart';
import 'package:ulab_bus/screens/bus_selection_screen.dart';
import 'package:ulab_bus/services/supabase_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isNewUser = false;
  String _errorMessage = '';

  Future<void> _login() async {
    if (_userIdController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError('Please enter your user ID and password');
      return;
    }

    if (_isNewUser && _nameController.text.isEmpty) {
      _showError('Please enter your name');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    AppLogger.info('Login attempt for user: ${_userIdController.text}', tag: 'AUTH');

    try {
      // Check if user exists
      final existingUser = await SupabaseService().getUser(_userIdController.text);

      if (_isNewUser) {
        // New user registration
        if (existingUser != null) {
          _showError('User ID already exists. Please login instead.');
          setState(() {
            _isLoading = false;
          });
          return;
        }

        // Determine user role based on user ID
        final role = _determineUserRole(_userIdController.text);

        final newUser = AppUser(
          userId: _userIdController.text,
          email: '${_userIdController.text}@ulab.edu',
          name: _nameController.text,
          role: role,
        );

        final success = await SupabaseService().createUser(newUser);

        if (!success) {
          _showError('Failed to create account. Please try again.');
          setState(() {
            _isLoading = false;
          });
          return;
        }

        AppLogger.success('New user registered: ${_userIdController.text}', tag: 'AUTH');

        // If driver, navigate to bus selection
        if (role == 'driver') {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => BusSelectionScreen(
                  driverId: _userIdController.text,
                  driverName: _nameController.text,
                ),
              ),
            );
          }
        } else {
          // If student, go to dashboard
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => StudentDashboard(
                  studentId: _userIdController.text,
                  studentName: _nameController.text,
                ),
              ),
            );
          }
        }
      } else {
        // Existing user login
        if (existingUser == null) {
          _showError('User not found. Please check your User ID or register as new user.');
          setState(() {
            _isLoading = false;
          });
          return;
        }

        AppLogger.success('Login successful for user: ${_userIdController.text}', tag: 'AUTH');

        // Navigate based on user role
        if (existingUser.role == 'driver') {
          // Check if driver has a bus assigned
          final driverBus = await SupabaseService().getDriverBus(existingUser.userId);

          if (mounted) {
            if (driverBus != null) {
              // Driver has a bus - go to dashboard
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => DriverDashboard(
                    driverId: existingUser.userId,
                    driverName: existingUser.name,
                    busNumber: driverBus.busNumber,
                  ),
                ),
              );
            } else {
              // Driver has no bus - go to bus selection
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => BusSelectionScreen(
                    driverId: existingUser.userId,
                    driverName: existingUser.name,
                  ),
                ),
              );
            }
          }
        } else {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => StudentDashboard(
                  studentId: existingUser.userId,
                  studentName: existingUser.name,
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      _showError('Login failed: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  String _determineUserRole(String userId) {
    if (userId.startsWith('8')) {
      return 'driver';
    } else {
      return 'student';
    }
  }

  void _showError(String message) {
    AppLogger.warning('Login error: $message', tag: 'AUTH');
    setState(() {
      _errorMessage = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
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
      backgroundColor: Colors.green[50],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Icon/Logo
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(60),
                  ),
                  child: const Icon(
                    Icons.directions_bus,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                Text(
                  'ULAB Bus System',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.green[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Smart Bus Tracking & Booking',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),

                // Error Message
                if (_errorMessage.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
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
                const SizedBox(height: 16),

                // Toggle between login and register
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isNewUser
                                ? () {
                              _clearError();
                              setState(() {
                                _isNewUser = false;
                              });
                            }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isNewUser ? Colors.grey[300] : Colors.green,
                              foregroundColor: _isNewUser ? Colors.grey : Colors.white,
                            ),
                            child: const Text('Login'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isNewUser
                                ? null
                                : () {
                              _clearError();
                              setState(() {
                                _isNewUser = true;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isNewUser ? Colors.green : Colors.grey[300],
                              foregroundColor: _isNewUser ? Colors.white : Colors.grey,
                            ),
                            child: const Text('Register'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Login Form
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        if (_isNewUser)
                          Column(
                            children: [
                              TextField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Full Name',
                                  prefixIcon: Icon(Icons.person),
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (_) => _clearError(),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        TextField(
                          controller: _userIdController,
                          decoration: const InputDecoration(
                            labelText: 'User ID',
                            prefixIcon: Icon(Icons.badge),
                            border: OutlineInputBorder(),
                            hintText: 'e.g., 222014052 (student) or 880 (driver)',
                          ),
                          onChanged: (_) => _clearError(),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock),
                            border: OutlineInputBorder(),
                            hintText: 'Any password for demo',
                          ),
                          onChanged: (_) => _clearError(),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : ElevatedButton(
                            onPressed: _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              _isNewUser ? 'REGISTER' : 'SIGN IN',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // User ID Guide
                const SizedBox(height: 24),
                Card(
                  color: Colors.green[100],
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          'User ID Guide',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• Student ID: Starts with 1-5 (e.g., 222014052)\n• Driver ID: Starts with 8 (e.g., 880, 881)\n• Password: Any value (for demo purposes)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}