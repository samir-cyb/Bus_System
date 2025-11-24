// lib/core/models.dart
class AppUser {
  final String userId;
  final String email;
  final String name;
  final String role;
  final String? busId;

  AppUser({
    required this.userId,
    required this.email,
    required this.name,
    required this.role,
    this.busId,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      userId: map['user_id'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? '',
      busId: map['bus_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'email': email,
      'name': name,
      'role': role,
      'bus_id': busId,
    };
  }
}

class Bus {
  final String busNumber;
  final String? licensePlate;
  final int? capacity;
  final bool isActive;
  final String? currentDriverId;

  Bus({
    required this.busNumber,
    this.licensePlate,
    this.capacity,
    required this.isActive,
    this.currentDriverId,
  });

  factory Bus.fromMap(Map<String, dynamic> map) {
    return Bus(
      busNumber: map['bus_number'] ?? '',
      licensePlate: map['license_plate'],
      capacity: map['capacity'],
      isActive: map['is_active'] ?? false,
      currentDriverId: map['current_driver_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bus_number': busNumber,
      'license_plate': licensePlate,
      'capacity': capacity,
      'is_active': isActive,
      'current_driver_id': currentDriverId,
    };
  }
}

class BusRoute {
  final String id;
  final String name;
  final String description;
  final bool isActive;
  final String? busId;

  BusRoute({
    required this.id,
    required this.name,
    required this.description,
    required this.isActive,
    this.busId,
  });

  factory BusRoute.fromMap(Map<String, dynamic> map) {
    return BusRoute(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      isActive: map['is_active'] ?? false,
      busId: map['bus_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'is_active': isActive,
      'bus_id': busId,
    };
  }
}

class BusStop {
  final String id;
  final String routeId;
  final String name;
  final double latitude;
  final double longitude;
  final int stopOrder;
  final double fareFromStart;

  BusStop({
    required this.id,
    required this.routeId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.stopOrder,
    required this.fareFromStart,
  });

  factory BusStop.fromMap(Map<String, dynamic> map) {
    return BusStop(
      id: map['id'] ?? '',
      routeId: map['route_id'] ?? '',
      name: map['name'] ?? '',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      stopOrder: map['stop_order'] ?? 0,
      fareFromStart: (map['fare_from_start'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'route_id': routeId,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'stop_order': stopOrder,
      'fare_from_start': fareFromStart,
    };
  }
}

class BusLocation {
  final String id;
  final String busId;
  final String driverId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double speed;
  final double heading;

  BusLocation({
    required this.id,
    required this.busId,
    required this.driverId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.speed,
    required this.heading,
  });

  factory BusLocation.fromMap(Map<String, dynamic> map) {
    return BusLocation(
      id: map['id'] ?? '',
      busId: map['bus_id'] ?? '',
      driverId: map['driver_id'] ?? '',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(map['timestamp']),
      speed: (map['speed'] as num).toDouble(),
      heading: (map['heading'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bus_id': busId,
      'driver_id': driverId,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'speed': speed,
      'heading': heading,
    };
  }
}

class Ticket {
  final String id;
  final String studentId;
  final String routeId;
  final String busId;
  final String startStopId;
  final String endStopId;
  final double fare;
  final DateTime purchaseTime;
  final bool isUsed;
  final DateTime? usageTime;

  Ticket({
    required this.id,
    required this.studentId,
    required this.routeId,
    required this.busId,
    required this.startStopId,
    required this.endStopId,
    required this.fare,
    required this.purchaseTime,
    required this.isUsed,
    this.usageTime,
  });

  factory Ticket.fromMap(Map<String, dynamic> map) {
    return Ticket(
      id: map['id'] ?? '',
      studentId: map['student_id'] ?? '',
      routeId: map['route_id'] ?? '',
      busId: map['bus_id'] ?? '',
      startStopId: map['start_stop_id'] ?? '',
      endStopId: map['end_stop_id'] ?? '',
      fare: (map['fare'] as num).toDouble(),
      purchaseTime: DateTime.parse(map['purchase_time']),
      isUsed: map['is_used'] ?? false,
      usageTime: map['usage_time'] != null ? DateTime.parse(map['usage_time']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'route_id': routeId,
      'bus_id': busId,
      'start_stop_id': startStopId,
      'end_stop_id': endStopId,
      'fare': fare,
      'purchase_time': purchaseTime.toIso8601String(),
      'is_used': isUsed,
      'usage_time': usageTime?.toIso8601String(),
    };
  }
}

class Alert {
  final String id;
  final String alertType;
  final String message;
  final String? busId;
  final String? driverId;
  final DateTime timestamp;

  Alert({
    required this.id,
    required this.alertType,
    required this.message,
    this.busId,
    this.driverId,
    required this.timestamp,
  });

  factory Alert.fromMap(Map<String, dynamic> map) {
    return Alert(
      id: map['id'] ?? '',
      alertType: map['alert_type'] ?? '',
      message: map['message'] ?? '',
      busId: map['bus_id'],
      driverId: map['driver_id'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'alert_type': alertType,
      'message': message,
      'bus_id': busId,
      'driver_id': driverId,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}