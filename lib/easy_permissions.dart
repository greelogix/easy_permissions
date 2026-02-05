// ignore_for_file: avoid_print


import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:developer' as developer;

class EasyPermissions {
  static final EasyPermissions _instance = EasyPermissions._internal();
  factory EasyPermissions() => _instance;
  EasyPermissions._internal();

  Map<String, bool> _config = {};

  /// Initialize from a Dart Map
  static void init(Map<String, dynamic> config) {
    _instance._config = config.map((key, value) => MapEntry(key, value == true));
  }

  /// Initialize from a JSON asset file
  static Future<void> initFromAsset(String path) async {
    try {
      final jsonString = await rootBundle.loadString(path);
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      init(jsonMap);
    } catch (e) {
      _logError("Failed to load configuration from asset: $path. Error: $e");
    }
  }

  /// Check if a permission is enabled in the configuration
  static bool isEnabled(String permission) {
    return _instance._config[permission] == true;
  }

  /// Request all enabled permissions
  static Future<Map<String, PermissionStatus>> ask() async {
    Map<String, PermissionStatus> results = {};
    for (var key in _instance._config.keys) {
      if (_instance._config[key] == true) {
        final permission = _getPermissionFromString(key);
        if (permission != null) {
          final status = await permission.request();
          results[key] = status;
        } else {
          _logWarning("Unknown permission key in config: $key");
        }
      }
    }
    return results;
  }

  /// Request a single permission
  static Future<PermissionStatus> askPermission(String permission) async {
    if (!_instance._config.containsKey(permission)) {
       _logWarning("Permission '$permission' is not present in the configuration.");
       return PermissionStatus.denied;
    }

    if (_instance._config[permission] != true) {
      _logWarning("Permission '$permission' is disabled in configuration (set to false).");
      return PermissionStatus.denied;
    }

    final perm = _getPermissionFromString(permission);
    if (perm == null) {
      _logError("Invalid permission key: $permission");
      return PermissionStatus.denied;
    }
    return await perm.request();
  }

  /// Check status of all enabled permissions
  static Future<Map<String, PermissionStatus>> checkStatus() async {
    Map<String, PermissionStatus> results = {};
     for (var key in _instance._config.keys) {
      if (_instance._config[key] == true) {
        final permission = _getPermissionFromString(key);
        if (permission != null) {
          final status = await permission.status;
          results[key] = status;
        }
      }
    }
    return results;
  }
  
   /// Check status for one permission
  static Future<PermissionStatus> checkPermission(String permission) async {
      final perm = _getPermissionFromString(permission);
      if (perm == null) return PermissionStatus.denied; 
      return await perm.status;
  }


  static Permission? _getPermissionFromString(String key) {
    switch (key.toLowerCase()) {
      case 'camera':
        return Permission.camera;
      case 'location':
        return Permission.location;
      case 'microphone':
        return Permission.microphone;
      case 'photos':
      case 'storage':
        // Note: Logic for photos/storage can be complex on Android 13+ vs below. 
        // Using photos for iOS and general media.
        return Permission.photos; 
      case 'contacts':
        return Permission.contacts;
      case 'notifications':
        return Permission.notification;
      case 'bluetooth':
        return Permission.bluetooth;
      case 'phone':
        return Permission.phone;
      case 'sensors':
        return Permission.sensors;
      // Add more as needed
      default:
        return null;
    }
  }

  static void _logWarning(String message) {
    // ANSI Red Bold
    developer.log('\x1B[1;31m⚠️ [EasyPermissions] $message\x1B[0m');
    print('\x1B[1;31m⚠️ [EasyPermissions] $message\x1B[0m');
  }

  static void _logError(String message) {
     developer.log('\x1B[1;31m❌ [EasyPermissions] $message\x1B[0m');
     print('\x1B[1;31m❌ [EasyPermissions] $message\x1B[0m');
  }
}
