import 'package:flutter/material.dart';
import 'package:easy_permissions_manager/easy_permissions_manager.dart';

void main() {
  EasyPermissions.init({'camera': true});
  runApp(const PermissionExample());
}

/// Minimal permission request triggered by a user action.
class PermissionExample extends StatelessWidget {
  /// Creates the example.
  const PermissionExample({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await EasyPermissions.request(Permission.camera);
          },
          child: const Text('Request camera'),
        ),
      ),
    ),
  );
}
