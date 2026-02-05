// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
export 'package:permission_handler/permission_handler.dart';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kIsWeb;

class EasyPermissions {
  static final EasyPermissions _instance = EasyPermissions._internal();
  factory EasyPermissions() => _instance;
  EasyPermissions._internal();

  Map<String, dynamic> _config = {};

  /// Initialize from a Dart Map
  static void init(Map<String, dynamic> config) {
    _instance._config = config;
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
    final val = _instance._config[permission];
    if (val is bool) return val;
    if (val is String) return val.isNotEmpty;
    if (val is Map) return val['required'] == true;
    return false;
  }

  /// Request all enabled permissions
  static Future<Map<String, PermissionStatus>> ask() async {
    Map<String, PermissionStatus> results = {};
    for (var key in _instance._config.keys) {
      if (isEnabled(key)) {
        if (kIsWeb && _isUnsupportedOnWeb(key)) {
          // Silently deny on web to avoid noise
          results[key] = PermissionStatus.denied;
          continue;
        }

        final permission = _getPermissionFromString(key);
        if (permission != null) {
          try {
            final status = await permission.request();
            results[key] = status;
          } catch (e) {
            _logWarning("Failed to request permission '$key': $e");
            results[key] = PermissionStatus.denied;
          }
        } else {
          _logWarning("Unknown permission key in config: $key");
        }
      }
    }
    return results;
  }

  /// Request a single permission using the type-safe API
  static Future<PermissionStatus> request(Permission permission) async {
    final key = _getKeyFromPermission(permission);
    if (key == null) {
      _logWarning(
        "Permission $permission is not supported by EasyPermissions config.",
      );
      return PermissionStatus.denied;
    }
    return askPermission(key);
  }

  /// Check status for one permission using the type-safe API
  static Future<PermissionStatus> check(Permission permission) async {
    final key = _getKeyFromPermission(permission);
    if (key == null) return PermissionStatus.denied;
    return checkPermission(key);
  }

  /// Request a single permission (String key)
  static Future<PermissionStatus> askPermission(String permission) async {
    if (!_instance._config.containsKey(permission)) {
      _logWarning(
        "Permission '$permission' is not present in the configuration.",
      );
      return PermissionStatus.denied;
    }

    if (!isEnabled(permission)) {
      _logWarning(
        "Permission '$permission' is disabled in configuration (set to false).",
      );
      return PermissionStatus.denied;
    }

    if (kIsWeb && _isUnsupportedOnWeb(permission)) {
      _logWarning(
        "Permission '$permission' is not supported on Web. Returning denied.",
      );
      return PermissionStatus.denied;
    }

    final perm = _getPermissionFromString(permission);
    if (perm == null) {
      _logError("Invalid permission key: $permission");
      return PermissionStatus.denied;
    }
    try {
      return await perm.request();
    } catch (e) {
      _logWarning("Failed to request permission '$permission': $e");
      return PermissionStatus.denied;
    }
  }

  /// Check status of all enabled permissions
  static Future<Map<String, PermissionStatus>> checkStatus() async {
    Map<String, PermissionStatus> results = {};
    for (var key in _instance._config.keys) {
      if (isEnabled(key)) {
        if (kIsWeb && _isUnsupportedOnWeb(key)) {
          results[key] = PermissionStatus.denied;
          continue;
        }

        final permission = _getPermissionFromString(key);
        if (permission != null) {
          try {
            final status = await permission.status;
            results[key] = status;
          } catch (e) {
            _logWarning("Failed to check status for '$key': $e");
            results[key] = PermissionStatus.denied;
          }
        }
      }
    }
    return results;
  }

  /// Check status for one permission
  static Future<PermissionStatus> checkPermission(String permission) async {
    if (kIsWeb && _isUnsupportedOnWeb(permission)) {
      return PermissionStatus.denied;
    }

    final perm = _getPermissionFromString(permission);
    if (perm == null) return PermissionStatus.denied;
    try {
      return await perm.status;
    } catch (e) {
      _logWarning("Failed to check status for '$permission': $e");
      return PermissionStatus.denied;
    }
  }

  static bool _isUnsupportedOnWeb(String key) {
    // List of permissions known to not be supported or commonly crashing on Web
    const unsupported = [
      'contacts',
      'bluetooth',
      'photos',
      'storage',
      'sensors',
      'phone',
      'notification',
    ];
    // 'notification' is tricky, but permission_handler might not support it fully on web depending on version.
    // For this user's logs, bluetooth, photos, contacts were the issue.
    return unsupported.contains(key.toLowerCase());
  }

  static String? _getKeyFromPermission(Permission permission) {
    if (permission == Permission.camera) {
      return 'camera';
    }
    if (permission == Permission.location) {
      return 'location';
    }
    if (permission == Permission.microphone) {
      return 'microphone';
    }
    if (permission == Permission.photos) {
      return 'photos';
    }
    if (permission == Permission.contacts) {
      return 'contacts';
    }
    if (permission == Permission.notification) {
      return 'notifications';
    }
    if (permission == Permission.bluetooth) {
      return 'bluetooth';
    }
    if (permission == Permission.phone) {
      return 'phone';
    }
    if (permission == Permission.sensors) {
      return 'sensors';
    }
    if (permission == Permission.storage) {
      return 'storage';
    }
    if (permission == Permission.mediaLibrary) {
      return 'photos'; // Map generic media to photos key if needed
    }
    return null;
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
