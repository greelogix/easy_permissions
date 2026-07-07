// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
export 'package:permission_handler/permission_handler.dart';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

export 'permission_result.dart';
import 'permission_result.dart';

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
  static Future<Map<String, PermissionResult>> ask() async {
    Map<String, PermissionResult> results = {};
    for (var key in _instance._config.keys) {
      if (isEnabled(key)) {
        results[key] = await askPermission(key);
      }
    }
    return results;
  }

  /// Request a single permission using the type-safe API
  static Future<PermissionResult> request(Permission permission) async {
    final key = _getKeyFromPermission(permission);
    if (key == null) {
      _logWarning(
        "Permission $permission is not supported by EasyPermissions config.",
      );
      return PermissionResult(
        status: PermissionStatus.restricted,
        isPermanentlyDenied: false,
        isSupported: false,
      );
    }
    return askPermission(key);
  }

  /// Check status for one permission using the type-safe API
  static Future<PermissionResult> check(Permission permission) async {
    final key = _getKeyFromPermission(permission);
    if (key == null) {
      return PermissionResult(
        status: PermissionStatus.restricted,
        isPermanentlyDenied: false,
        isSupported: false,
      );
    }
    return checkPermission(key);
  }

  /// Request a single permission (String key)
  static Future<PermissionResult> askPermission(String permission) async {
    if (!_instance._config.containsKey(permission)) {
      _logWarning(
        "Permission '$permission' is not present in the configuration.",
      );
      return PermissionResult(
        status: PermissionStatus.denied,
        isPermanentlyDenied: false,
      );
    }

    if (!isEnabled(permission)) {
      _logWarning(
        "Permission '$permission' is disabled in configuration (set to false).",
      );
      return PermissionResult(
        status: PermissionStatus.denied,
        isPermanentlyDenied: false,
      );
    }

    if (_isUnsupportedOnCurrentPlatform(permission)) {
      _logWarning(
        "Permission '$permission' is not supported on this platform. Returning restricted.",
      );
      return PermissionResult(
        status: PermissionStatus.restricted,
        isPermanentlyDenied: false,
        isSupported: false,
      );
    }

    // Android 12+ Bluetooth handling
    if (permission.toLowerCase() == 'bluetooth' && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final statuses = await [
          Permission.bluetooth,
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
        ].request();
        
        // Aggregate results
        bool isPermanentlyDenied = statuses.values.any((s) => s.isPermanentlyDenied);
        bool isGranted = statuses.values.every((s) => s.isGranted);
        
        return PermissionResult(
          status: isGranted ? PermissionStatus.granted : (isPermanentlyDenied ? PermissionStatus.permanentlyDenied : PermissionStatus.denied),
          isPermanentlyDenied: isPermanentlyDenied,
          isSupported: true,
        );
      } catch (e) {
        _logWarning("Failed to request bluetooth permissions: $e");
        return PermissionResult(
          status: PermissionStatus.denied,
          isPermanentlyDenied: false,
        );
      }
    }

    final perm = _getPermissionFromString(permission);
    if (perm == null) {
      _logError("Invalid permission key: $permission");
      return PermissionResult(
        status: PermissionStatus.restricted,
        isPermanentlyDenied: false,
        isSupported: false,
      );
    }
    try {
      final status = await perm.request();
      bool isPermanentlyDenied = false;
      try {
        isPermanentlyDenied = status.isPermanentlyDenied;
      } catch (_) {
        // isPermanentlyDenied might not be supported on some platforms
        isPermanentlyDenied = false;
      }
      return PermissionResult(
        status: status,
        isPermanentlyDenied: isPermanentlyDenied,
      );
    } catch (e) {
      _logWarning("Failed to request permission '$permission': $e");
      return PermissionResult(
        status: PermissionStatus.denied,
        isPermanentlyDenied: false,
      );
    }
  }

  /// Check status of all enabled permissions
  static Future<Map<String, PermissionResult>> checkStatus() async {
    Map<String, PermissionResult> results = {};
    for (var key in _instance._config.keys) {
      if (isEnabled(key)) {
        results[key] = await checkPermission(key);
      }
    }
    return results;
  }

  /// Check status for one permission
  static Future<PermissionResult> checkPermission(String permission) async {
    if (_isUnsupportedOnCurrentPlatform(permission)) {
      return PermissionResult(
        status: PermissionStatus.restricted,
        isPermanentlyDenied: false,
        isSupported: false,
      );
    }

    // Android 12+ Bluetooth handling
    if (permission.toLowerCase() == 'bluetooth' && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final bStatus = await Permission.bluetooth.status;
        final bsStatus = await Permission.bluetoothScan.status;
        final bcStatus = await Permission.bluetoothConnect.status;
        
        final statuses = [bStatus, bsStatus, bcStatus];
        bool isPermanentlyDenied = statuses.any((s) => s.isPermanentlyDenied);
        bool isGranted = statuses.every((s) => s.isGranted);
        
        return PermissionResult(
          status: isGranted ? PermissionStatus.granted : (isPermanentlyDenied ? PermissionStatus.permanentlyDenied : PermissionStatus.denied),
          isPermanentlyDenied: isPermanentlyDenied,
          isSupported: true,
        );
      } catch (e) {
        _logWarning("Failed to check bluetooth status: $e");
        return PermissionResult(
          status: PermissionStatus.denied,
          isPermanentlyDenied: false,
        );
      }
    }

    final perm = _getPermissionFromString(permission);
    if (perm == null) {
      return PermissionResult(
        status: PermissionStatus.restricted,
        isPermanentlyDenied: false,
        isSupported: false,
      );
    }
    try {
      final status = await perm.status;
      bool isPermanentlyDenied = false;
      try {
        isPermanentlyDenied = status.isPermanentlyDenied;
      } catch (_) {
        // isPermanentlyDenied might not be supported on some platforms
        isPermanentlyDenied = false;
      }
      return PermissionResult(
        status: status,
        isPermanentlyDenied: isPermanentlyDenied,
      );
    } catch (e) {
      _logWarning("Failed to check status for '$permission': $e");
      return PermissionResult(
        status: PermissionStatus.denied,
        isPermanentlyDenied: false,
      );
    }
  }

  /// Open app settings for the user to manually grant permissions
  static Future<bool> openSettings() async {
    try {
      // Check if platform supports opening settings
      if (kIsWeb) {
        _logWarning("Opening app settings is not supported natively on Web.");
        return false;
      }
      if (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        _logWarning("Opening app settings is not natively supported on desktop platforms.");
        return false;
      }
      return await openAppSettings();
    } catch (e) {
      _logError("Failed to open app settings: $e");
      return false;
    }
  }

  static bool _isUnsupportedOnCurrentPlatform(String key) {
    if (kIsWeb) {
      const webUnsupported = [
        'contacts',
        'bluetooth',
        'photos',
        'storage',
        'sensors',
        'phone',
        'reminders',
        'calendar',
        'speech',
        'ignoreBatteryOptimizations',
        'requestInstallPackages',
        'appTrackingTransparency',
        'criticalAlerts',
        'accessNotificationPolicy',
        'activityRecognition',
      ];
      return webUnsupported.contains(key.toLowerCase());
    }
    if (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      // permission_handler doesn't fully support desktop platforms natively without heavy lifting
      return true;
    }
    return false;
  }

  static String? _getKeyFromPermission(Permission permission) {
    if (permission == Permission.camera) {
      return 'camera';
    }
    if (permission == Permission.location) {
      return 'location';
    }
    if (permission == Permission.locationAlways) {
      return 'location';
    }
    if (permission == Permission.locationWhenInUse) {
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
    if (permission == Permission.bluetoothScan) {
      return 'bluetooth';
    }
    if (permission == Permission.bluetoothConnect) {
      return 'bluetooth';
    }
    if (permission == Permission.bluetoothAdvertise) {
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
      return 'photos';
    }
    if (permission == Permission.photosAddOnly) {
      return 'photos';
    }
    if (permission == Permission.reminders) {
      return 'reminders';
    }
    if (permission == Permission.calendarFullAccess) {
      return 'calendar';
    }
    if (permission == Permission.calendarWriteOnly) {
      return 'calendar';
    }
    if (permission == Permission.calendarFullAccess) {
      return 'calendar';
    }
    if (permission == Permission.speech) {
      return 'speech';
    }
    if (permission == Permission.ignoreBatteryOptimizations) {
      return 'ignoreBatteryOptimizations';
    }
    if (permission == Permission.requestInstallPackages) {
      return 'requestInstallPackages';
    }
    if (permission == Permission.appTrackingTransparency) {
      return 'appTrackingTransparency';
    }
    if (permission == Permission.criticalAlerts) {
      return 'criticalAlerts';
    }
    if (permission == Permission.accessNotificationPolicy) {
      return 'accessNotificationPolicy';
    }
    if (permission == Permission.activityRecognition) {
      return 'activityRecognition';
    }
    if (permission == Permission.unknown) {
      return 'unknown';
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
        return Permission.photos;
      case 'contacts':
        return Permission.contacts;
      case 'notifications':
        return Permission.notification;
      case 'bluetooth':
        // On Android 12+, we should use Bluetooth specific permissions
        if (defaultTargetPlatform == TargetPlatform.android) {
          // For backward compatibility, still return Permission.bluetooth, but also support individual ones
          return Permission.bluetooth;
        }
        return Permission.bluetooth;
      case 'phone':
        return Permission.phone;
      case 'sensors':
        return Permission.sensors;
      case 'reminders':
        return Permission.reminders;
      case 'calendar':
        return Permission.calendarFullAccess;
      case 'speech':
        return Permission.speech;
      case 'ignorebatteryoptimizations':
        return Permission.ignoreBatteryOptimizations;
      case 'requestinstallpackages':
        return Permission.requestInstallPackages;
      case 'apptrackingtransparency':
        return Permission.appTrackingTransparency;
      case 'criticalalerts':
        return Permission.criticalAlerts;
      case 'accessnotificationpolicy':
        return Permission.accessNotificationPolicy;
      case 'activityrecognition':
        return Permission.activityRecognition;
      default:
        return null;
    }
  }

  static void _logWarning(String message) {
    developer.log('\x1B[1;33m⚠️ [EasyPermissions] $message\x1B[0m');
    print('\x1B[1;33m⚠️ [EasyPermissions] $message\x1B[0m');
  }

  static void _logError(String message) {
    developer.log('\x1B[1;31m❌ [EasyPermissions] $message\x1B[0m');
    print('\x1B[1;31m❌ [EasyPermissions] $message\x1B[0m');
  }
}
