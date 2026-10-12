import 'package:permission_handler/permission_handler.dart';

/// A class to hold permission result details including status and whether it's permanently denied
class PermissionResult {
  /// The native permission status.
  final PermissionStatus status;

  /// Whether subsequent requests require a trip to app settings.
  final bool isPermanentlyDenied;

  /// Whether the permission is available through this platform backend.
  final bool isSupported;

  /// Creates an immutable permission result.
  const PermissionResult({
    required this.status,
    required this.isPermanentlyDenied,
    this.isSupported = true,
  });

  @override
  String toString() {
    return 'PermissionResult{status: $status, isPermanentlyDenied: $isPermanentlyDenied, isSupported: $isSupported}';
  }
}
