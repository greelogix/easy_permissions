import 'package:permission_handler/permission_handler.dart';

/// A class to hold permission result details including status and whether it's permanently denied
class PermissionResult {
  final PermissionStatus status;
  final bool isPermanentlyDenied;
  final bool isSupported;

  PermissionResult({
    required this.status,
    required this.isPermanentlyDenied,
    this.isSupported = true,
  });

  @override
  String toString() {
    return 'PermissionResult{status: $status, isPermanentlyDenied: $isPermanentlyDenied, isSupported: $isSupported}';
  }
}
