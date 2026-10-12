// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
export 'package:permission_handler/permission_handler.dart';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'src/configuration.dart';
import 'permission_result.dart';
export 'permission_result.dart';

/// Configures, checks, and requests permissions through permission_handler.
class EasyPermissions {
  static final EasyPermissions _instance = EasyPermissions._internal();

  /// Returns the shared permission manager.
  factory EasyPermissions() => _instance;
  EasyPermissions._internal();

  Map<String, dynamic> _config = {};

  // ─── Initialisation ────────────────────────────────────────────────────────

  /// Initialize from a Dart [Map].
  static void init(Map<String, dynamic> config) {
    _instance._config = normalizeConfig(config);
  }

  /// Initialize from a raw JSON [String].
  ///
  /// Useful for testing or when config is fetched from a remote source:
  /// ```dart
  /// await EasyPermissions.initFromString(await http.read(Uri.parse(url)));
  /// ```
  static void initFromString(String jsonString) {
    try {
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      init(jsonMap);
    } catch (e) {
      reset();
      _logError('Failed to parse JSON string. Error: $e');
    }
  }

  /// Initialize from a JSON asset file.
  static Future<void> initFromAsset(String path) async {
    try {
      final jsonString = await rootBundle.loadString(path);
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      init(jsonMap);
    } catch (e) {
      reset();
      _logError('Failed to load configuration from asset: $path. Error: $e');
    }
  }

  /// Clear the current configuration and reset the instance to its initial
  /// state. Useful between tests.
  static void reset() {
    _instance._config = {};
  }

  // ─── Config helpers ─────────────────────────────────────────────────────────

  /// Returns `true` if [permission] is enabled in the loaded configuration.
  static bool isEnabled(String permission) {
    return enabledValue(_instance._config[permissionKey(permission)]);
  }

  // ─── Request ────────────────────────────────────────────────────────────────

  /// Request all enabled permissions defined in the configuration.
  static Future<Map<String, PermissionStatus>> ask() async {
    final results = <String, PermissionStatus>{};
    for (final key in _instance._config.keys.toList()) {
      if (isEnabled(key)) results[key] = await askPermission(key);
    }
    return results;
  }

  /// Request a single permission using the type-safe [Permission] API.
  static Future<PermissionStatus> request(Permission permission) async {
    final key = _getKeyFromPermission(permission);
    if (key == null) {
      _logWarning(
        'Permission $permission is not supported by EasyPermissions config.',
      );
      return PermissionStatus.denied;
    }
    if (!isEnabled(key) || _isUnsupportedOnCurrentPlatform(key)) {
      return PermissionStatus.denied;
    }
    try {
      return await permission.request();
    } catch (e) {
      _logWarning('Failed to request $permission: $e');
      return PermissionStatus.denied;
    }
  }

  /// Request a single permission by its string key (e.g. `'camera'`).
  static Future<PermissionStatus> askPermission(String permission) async {
    permission = permissionKey(permission);
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

    if (_isUnsupportedOnCurrentPlatform(permission)) {
      _logWarning(
        "Permission '$permission' is not supported on Web. Returning denied.",
      );
      return PermissionStatus.denied;
    }

    final perm = _getPermissionFromString(permission);
    if (perm == null) {
      _logError('Invalid permission key: $permission');
      return PermissionStatus.denied;
    }
    try {
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android &&
          permission == 'bluetooth') {
        return _aggregate(
          (await [
            Permission.bluetoothScan,
            Permission.bluetoothConnect,
          ].request()).values,
        );
      }
      return await perm.request();
    } catch (e) {
      _logWarning("Failed to request permission '$permission': $e");
      return PermissionStatus.denied;
    }
  }

  // ─── Check ──────────────────────────────────────────────────────────────────

  /// Check the status of a single permission using the type-safe [Permission] API.
  static Future<PermissionStatus> check(Permission permission) async {
    final key = _getKeyFromPermission(permission);
    if (key == null) return PermissionStatus.denied;
    if (_isUnsupportedOnCurrentPlatform(key)) return PermissionStatus.denied;
    try {
      return await permission.status;
    } catch (e) {
      _logWarning('Failed to check $permission: $e');
      return PermissionStatus.denied;
    }
  }

  /// Check the status of all enabled permissions without requesting them.
  static Future<Map<String, PermissionStatus>> checkStatus() async {
    final results = <String, PermissionStatus>{};
    for (final key in _instance._config.keys.toList()) {
      if (isEnabled(key)) results[key] = await checkPermission(key);
    }
    return results;
  }

  /// Check the status of a single permission by its string key.
  static Future<PermissionStatus> checkPermission(String permission) async {
    permission = permissionKey(permission);
    if (_isUnsupportedOnCurrentPlatform(permission)) {
      return PermissionStatus.denied;
    }

    final perm = _getPermissionFromString(permission);
    if (perm == null) return PermissionStatus.denied;
    try {
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android &&
          permission == 'bluetooth') {
        return _aggregate(
          await Future.wait([
            Permission.bluetoothScan.status,
            Permission.bluetoothConnect.status,
          ]),
        );
      }
      return await perm.status;
    } catch (e) {
      _logWarning("Failed to check status for '$permission': $e");
      return PermissionStatus.denied;
    }
  }

  // ─── Settings ───────────────────────────────────────────────────────────────

  /// Open the device app-settings page.
  ///
  /// Call this when a permission is [PermissionStatus.permanentlyDenied] — the
  /// only way to re-grant it is through the system settings screen.
  ///
  /// ```dart
  /// if (status.isPermanentlyDenied) {
  ///   await EasyPermissions.openSettings();
  /// }
  /// ```
  static Future<bool> openSettings() async {
    if (kIsWeb || _isUnsupportedOnCurrentPlatform('camera')) return false;
    try {
      return await openAppSettings();
    } catch (e) {
      _logWarning('Failed to open app settings: $e');
      return false;
    }
  }

  // ─── Internal helpers ───────────────────────────────────────────────────────

  /// Permissions that crash or are unsupported on the web platform.
  static bool _isUnsupportedOnCurrentPlatform(String key) {
    if (!kIsWeb) {
      return defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.fuchsia;
    }
    return !{
      'camera',
      'microphone',
      'location',
      'locationwheninuse',
    }.contains(permissionKey(key));
  }

  static String? _getKeyFromPermission(Permission permission) {
    if (permission == Permission.camera) return 'camera';
    if (permission == Permission.location) return 'location';
    if (permission == Permission.locationAlways) return 'locationAlways';
    if (permission == Permission.microphone) return 'microphone';
    if (permission == Permission.photos) return 'photos';
    if (permission == Permission.contacts) return 'contacts';
    if (permission == Permission.notification) return 'notifications';
    if (permission == Permission.bluetooth) return 'bluetooth';
    if (permission == Permission.phone) return 'phone';
    if (permission == Permission.sensors) return 'sensors';
    if (permission == Permission.storage) return 'storage';
    if (permission == Permission.mediaLibrary) return 'medialibrary';
    if (permission == Permission.locationWhenInUse) return 'location';
    if (permission == Permission.photosAddOnly) return 'photos';
    if (permission == Permission.bluetoothScan ||
        permission == Permission.bluetoothConnect ||
        permission == Permission.bluetoothAdvertise) {
      return 'bluetooth';
    }
    return null;
  }

  static Permission? _getPermissionFromString(String key) {
    switch (key.toLowerCase()) {
      case 'camera':
        return Permission.camera;
      case 'location':
        return Permission.location;
      // Always-on background location — requires explicit config key.
      case 'locationalways':
        return Permission.locationAlways;
      case 'microphone':
        return Permission.microphone;
      case 'photos':
        return Permission.photos;
      case 'medialibrary':
        return Permission.mediaLibrary;
      case 'storage':
        return Permission.storage;
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
      default:
        return null;
    }
  }

  /// Requests one permission and reports support and permanent denial separately.
  static Future<PermissionResult> requestDetailed(Permission permission) async {
    final key = _getKeyFromPermission(permission);
    final status = await request(permission);
    return _result(status, key);
  }

  /// Checks one permission without triggering an operating-system prompt.
  static Future<PermissionResult> checkDetailed(Permission permission) async {
    final key = _getKeyFromPermission(permission);
    return _result(await check(permission), key);
  }

  /// Requests a configured permission and returns detailed support information.
  static Future<PermissionResult> askPermissionDetailed(String key) async =>
      _result(await askPermission(key), key);

  /// Checks a permission and returns detailed support information.
  static Future<PermissionResult> checkPermissionDetailed(String key) async =>
      _result(await checkPermission(key), key);

  /// Requests all enabled permissions with detailed results.
  static Future<Map<String, PermissionResult>> askDetailed() async =>
      (await ask()).map((key, status) => MapEntry(key, _result(status, key)));

  /// Checks all enabled permissions with detailed results.
  static Future<Map<String, PermissionResult>> checkStatusDetailed() async =>
      (await checkStatus()).map(
        (key, status) => MapEntry(key, _result(status, key)),
      );

  static PermissionResult _result(PermissionStatus status, String? key) =>
      PermissionResult(
        status: status,
        isPermanentlyDenied: status.isPermanentlyDenied,
        isSupported:
            key != null &&
            _getPermissionFromString(key) != null &&
            !_isUnsupportedOnCurrentPlatform(key),
      );

  static PermissionStatus _aggregate(Iterable<PermissionStatus> statuses) {
    final values = statuses.toList();
    if (values.isEmpty) return PermissionStatus.denied;
    if (values.every((status) => status.isGranted)) {
      return PermissionStatus.granted;
    }
    if (values.any((status) => status.isPermanentlyDenied)) {
      return PermissionStatus.permanentlyDenied;
    }
    return PermissionStatus.denied;
  }

  static void _logWarning(String message) {
    developer.log(
      '⚠️ [EasyPermissions] $message',
      name: 'EasyPermissions',
      level: 900,
    );
    if (kIsWeb) print('⚠️ [EasyPermissions] $message');
  }

  static void _logError(String message) {
    developer.log(
      '❌ [EasyPermissions] $message',
      name: 'EasyPermissions',
      level: 1000,
    );
    if (kIsWeb) print('❌ [EasyPermissions] $message');
  }
}
