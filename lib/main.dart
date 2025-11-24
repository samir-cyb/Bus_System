import 'package:flutter/material.dart';
import 'package:ulab_bus/core/logger.dart';
import 'package:ulab_bus/screens/login_screen.dart';
import 'package:ulab_bus/services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.info('ULAB Bus App starting...', tag: 'MAIN');

  try {
    // Initialize Supabase
    await SupabaseService().initialize();

    // Check if database is properly set up
    final isSetUp = await SupabaseService().isDatabaseSetUp();
    if (!isSetUp) {
      AppLogger.warning('Database not properly set up. Some features may not work.', tag: 'MAIN');
    }

    runApp(const ULABBusApp());
  } catch (e) {
    AppLogger.error('Failed to initialize app', tag: 'MAIN', error: e);
    runApp(const ErrorApp());
  }
}

class ULABBusApp extends StatelessWidget {
  const ULABBusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ULAB Bus System',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red),
                SizedBox(height: 20),
                Text(
                  'App Initialization Failed',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  'Please check your internet connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => main(),
                  child: Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}