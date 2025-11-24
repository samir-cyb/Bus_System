import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ulab_bus/core/logger.dart';
import 'package:ulab_bus/core/models.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  static const String _supabaseUrl = 'https://tqmyqwjrsypkibaryrkb.supabase.co';
  static const String _supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRxbXlxd2pyc3lwa2liYXJ5cmtiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM5MTYzMjcsImV4cCI6MjA3OTQ5MjMyN30.l2QOHWeGfU8CqgwQ9GprwveG4apo9u2cBt5aMvOAU5w';

  late final SupabaseClient _client;
  bool _isInitialized = false;

  Future<void> initialize() async {
    try {
      AppLogger.debug('Initializing Supabase...', tag: 'SUPABASE');
      await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseKey);
      _client = Supabase.instance.client;
      _isInitialized = true;
      AppLogger.success('Supabase initialized successfully', tag: 'SUPABASE');

      // Test connection and schema
      final isSetUp = await isDatabaseSetUp();
      if (isSetUp) {
        AppLogger.success('Database schema is properly set up', tag: 'SUPABASE');
      } else {
        AppLogger.error('Database schema is not set up correctly. Please run the setup SQL.', tag: 'SUPABASE');
      }
    } catch (e) {
      AppLogger.error('Failed to initialize Supabase', tag: 'SUPABASE', error: e);
      rethrow;
    }
  }

  void _checkInitialization() {
    if (!_isInitialized) {
      throw Exception('SupabaseService not initialized. Call initialize() first.');
    }
  }

  // User methods
  Future<AppUser?> getUser(String userId) async {
    _checkInitialization();
    try {
      AppLogger.debug('Fetching user: $userId', tag: 'SUPABASE');
      final response = await _client
          .from('users')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        AppLogger.debug('User found: $userId', tag: 'SUPABASE');
        return AppUser.fromMap(response as Map<String, dynamic>);
      }
      AppLogger.debug('User not found: $userId', tag: 'SUPABASE');
      return null;
    } catch (e) {
      AppLogger.error('Failed to get user: $userId', tag: 'SUPABASE', error: e);
      return null;
    }
  }

  Future<bool> createUser(AppUser user) async {
    _checkInitialization();
    try {
      AppLogger.debug('Creating user: ${user.userId}', tag: 'SUPABASE');

      // First check if user already exists
      final existingUser = await getUser(user.userId);
      if (existingUser != null) {
        AppLogger.warning('User already exists: ${user.userId}', tag: 'SUPABASE');
        return false;
      }

      await _client
          .from('users')
          .insert(user.toMap());

      AppLogger.success('User created successfully: ${user.userId}', tag: 'SUPABASE');
      return true;
    } catch (e) {
      AppLogger.error('Failed to create user: ${user.userId}', tag: 'SUPABASE', error: e);

      // Provide specific error messages for common issues
      if (e.toString().contains('role')) {
        AppLogger.error('Database schema issue: "role" column might be missing. Run the setup SQL.', tag: 'SUPABASE');
      } else if (e.toString().contains('user_type')) {
        AppLogger.error('Database has wrong schema: has "user_type" instead of "role". Run the setup SQL.', tag: 'SUPABASE');
      } else if (e.toString().contains('users')) {
        AppLogger.error('Database schema issue: "users" table might be missing. Run the setup SQL.', tag: 'SUPABASE');
      }

      return false;
    }
  }

  // Bus methods
  Future<List<Bus>> getAvailableBuses() async {
    _checkInitialization();
    try {
      AppLogger.debug('Fetching available buses', tag: 'SUPABASE');
      final response = await _client
          .from('buses')
          .select()
          .eq('is_active', true);

      if (response != null && response is List) {
        final buses = response
            .map((item) => Bus.fromMap(item as Map<String, dynamic>))
            .toList();
        AppLogger.debug('Found ${buses.length} available buses', tag: 'SUPABASE');
        return buses;
      }
      AppLogger.debug('No available buses found', tag: 'SUPABASE');
      return [];
    } catch (e) {
      AppLogger.error('Failed to get buses', tag: 'SUPABASE', error: e);
      return [];
    }
  }

  Future<bool> assignBusToDriver(String userId, String busId) async {
    _checkInitialization();
    try {
      AppLogger.debug('Assigning bus $busId to driver $userId', tag: 'SUPABASE');

      // Update user with bus assignment
      await _client
          .from('users')
          .update({'bus_id': busId})
          .eq('user_id', userId);

      // Update bus with driver assignment
      await _client
          .from('buses')
          .update({'current_driver_id': userId})
          .eq('bus_number', busId);

      AppLogger.success('Bus $busId assigned to driver $userId', tag: 'SUPABASE');
      return true;
    } catch (e) {
      AppLogger.error('Failed to assign bus $busId to driver $userId', tag: 'SUPABASE', error: e);
      return false;
    }
  }

  // Route methods
  Future<List<BusRoute>> getRoutes() async {
    _checkInitialization();
    try {
      AppLogger.debug('Fetching routes', tag: 'SUPABASE');
      final response = await _client
          .from('routes')
          .select()
          .eq('is_active', true);

      if (response != null && response is List) {
        final routes = response
            .map((item) => BusRoute.fromMap(item as Map<String, dynamic>))
            .toList();
        AppLogger.debug('Found ${routes.length} routes', tag: 'SUPABASE');
        return routes;
      }
      AppLogger.debug('No routes found', tag: 'SUPABASE');
      return [];
    } catch (e) {
      AppLogger.error('Failed to get routes', tag: 'SUPABASE', error: e);
      return [];
    }
  }

  Future<List<BusStop>> getStopsForRoute(String routeId) async {
    _checkInitialization();
    try {
      AppLogger.debug('Fetching stops for route: $routeId', tag: 'SUPABASE');
      final response = await _client
          .from('stops')
          .select()
          .eq('route_id', routeId)
          .order('stop_order');

      if (response != null && response is List) {
        final stops = response
            .map((item) => BusStop.fromMap(item as Map<String, dynamic>))
            .toList();
        AppLogger.debug('Found ${stops.length} stops for route $routeId', tag: 'SUPABASE');
        return stops;
      }
      AppLogger.debug('No stops found for route $routeId', tag: 'SUPABASE');
      return [];
    } catch (e) {
      AppLogger.error('Failed to get stops for route: $routeId', tag: 'SUPABASE', error: e);
      return [];
    }
  }

  // Location methods
  Future<bool> updateBusLocation(BusLocation location) async {
    _checkInitialization();
    try {
      AppLogger.debug('Updating location for bus: ${location.busId}', tag: 'SUPABASE');
      await _client
          .from('bus_locations')
          .upsert(location.toMap());
      AppLogger.debug('Location updated for bus: ${location.busId}', tag: 'SUPABASE');
      return true;
    } catch (e) {
      AppLogger.error('Failed to update location for bus: ${location.busId}', tag: 'SUPABASE', error: e);
      return false;
    }
  }

  Stream<List<BusLocation>> getBusLocationsStream() {
    _checkInitialization();
    AppLogger.debug('Setting up bus locations stream', tag: 'SUPABASE');
    return _client
        .from('bus_locations')
        .stream(primaryKey: ['id'])
        .order('timestamp', ascending: false)
        .map((list) {
      AppLogger.debug('Received ${list.length} bus locations', tag: 'SUPABASE');
      return list.map((item) => BusLocation.fromMap(item)).toList();
    });
  }

  // Ticket methods
  Future<Ticket?> createTicket(Ticket ticket) async {
    _checkInitialization();
    try {
      AppLogger.debug('Creating ticket for student: ${ticket.studentId}', tag: 'SUPABASE');
      final response = await _client
          .from('tickets')
          .insert(ticket.toMap())
          .select()
          .single();

      AppLogger.success('Ticket created for student: ${ticket.studentId}', tag: 'SUPABASE');
      return Ticket.fromMap(response as Map<String, dynamic>);
    } catch (e) {
      AppLogger.error('Failed to create ticket for student: ${ticket.studentId}', tag: 'SUPABASE', error: e);
      return null;
    }
  }

  Future<List<Ticket>> getStudentTickets(String studentId) async {
    _checkInitialization();
    try {
      AppLogger.debug('Fetching tickets for student: $studentId', tag: 'SUPABASE');
      final response = await _client
          .from('tickets')
          .select()
          .eq('student_id', studentId)
          .order('purchase_time', ascending: false);

      if (response != null && response is List) {
        final tickets = response
            .map((item) => Ticket.fromMap(item as Map<String, dynamic>))
            .toList();
        AppLogger.debug('Found ${tickets.length} tickets for student $studentId', tag: 'SUPABASE');
        return tickets;
      }
      AppLogger.debug('No tickets found for student $studentId', tag: 'SUPABASE');
      return [];
    } catch (e) {
      AppLogger.error('Failed to get tickets for student: $studentId', tag: 'SUPABASE', error: e);
      return [];
    }
  }

  // Alert methods
  Future<bool> sendAlert(Alert alert) async {
    _checkInitialization();
    try {
      AppLogger.debug('Sending alert: ${alert.alertType}', tag: 'SUPABASE');
      await _client
          .from('alerts')
          .insert(alert.toMap());
      AppLogger.success('Alert sent: ${alert.alertType}', tag: 'SUPABASE');
      return true;
    } catch (e) {
      AppLogger.error('Failed to send alert: ${alert.alertType}', tag: 'SUPABASE', error: e);
      return false;
    }
  }

  Future<List<Alert>> getRecentAlerts() async {
    _checkInitialization();
    try {
      AppLogger.debug('Fetching recent alerts', tag: 'SUPABASE');
      final response = await _client
          .from('alerts')
          .select()
          .order('timestamp', ascending: false)
          .limit(10);

      if (response != null && response is List) {
        final alerts = response
            .map((item) => Alert.fromMap(item as Map<String, dynamic>))
            .toList();
        AppLogger.debug('Found ${alerts.length} recent alerts', tag: 'SUPABASE');
        return alerts;
      }
      AppLogger.debug('No recent alerts found', tag: 'SUPABASE');
      return [];
    } catch (e) {
      AppLogger.error('Failed to get alerts', tag: 'SUPABASE', error: e);
      return [];
    }
  }

  // Check if database is properly set up
  Future<bool> isDatabaseSetUp() async {
    try {
      final tables = ['users', 'buses', 'routes', 'stops', 'bus_locations', 'tickets', 'alerts'];

      for (var table in tables) {
        try {
          await _client.from(table).select().limit(1);
          AppLogger.debug('Table $table is accessible', tag: 'SUPABASE');
        } catch (e) {
          AppLogger.error('Table $table is missing or inaccessible', tag: 'SUPABASE', error: e);
          return false;
        }
      }

      return true;
    } catch (e) {
      AppLogger.error('Database setup check failed', tag: 'SUPABASE', error: e);
      return false;
    }
  }

  // Get driver's assigned bus
  Future<Bus?> getDriverBus(String driverId) async {
    _checkInitialization();
    try {
      AppLogger.debug('Fetching bus for driver: $driverId', tag: 'SUPABASE');

      // First get user to find bus_id
      final user = await getUser(driverId);
      if (user == null || user.busId == null) {
        AppLogger.debug('Driver $driverId has no assigned bus', tag: 'SUPABASE');
        return null;
      }

      final response = await _client
          .from('buses')
          .select()
          .eq('bus_number', user.busId!)
          .maybeSingle();

      if (response != null) {
        AppLogger.debug('Found bus for driver $driverId: ${user.busId}', tag: 'SUPABASE');
        return Bus.fromMap(response as Map<String, dynamic>);
      }

      AppLogger.debug('Bus not found for driver $driverId: ${user.busId}', tag: 'SUPABASE');
      return null;
    } catch (e) {
      AppLogger.error('Failed to get driver bus: $driverId', tag: 'SUPABASE', error: e);
      return null;
    }
  }
}