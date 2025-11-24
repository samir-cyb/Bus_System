import 'package:flutter/foundation.dart';

class AppLogger {
  static void info(String message, {String? tag}) {
    if (kDebugMode) {
      print('ℹ️ [${tag ?? 'ULAB_BUS'}] $message');
    }
  }

  static void debug(String message, {String? tag}) {
    if (kDebugMode) {
      print('🐛 [${tag ?? 'ULAB_BUS'}] $message');
    }
  }

  static void warning(String message, {String? tag}) {
    if (kDebugMode) {
      print('⚠️ [${tag ?? 'ULAB_BUS'}] $message');
    }
  }

  static void error(String message, {String? tag, dynamic error}) {
    if (kDebugMode) {
      print('❌ [${tag ?? 'ULAB_BUS'}] $message ${error != null ? 'Error: $error' : ''}');
    }
  }

  static void success(String message, {String? tag}) {
    if (kDebugMode) {
      print('✅ [${tag ?? 'ULAB_BUS'}] $message');
    }
  }
}