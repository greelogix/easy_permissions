import 'package:flutter/material.dart';
import 'package:easy_permissions/easy_permissions.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize with Dart Map
  EasyPermissions.init({
    "camera": true,
    "location": true,
    "microphone": false,
    "photos": true,
    "contacts": false,
    "notifications": true
  });

  // Alternatively:
  // await EasyPermissions.initFromAsset('assets/easy_permissions.json');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text("Easy Permissions Example")),
        body: Center(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Camera enabled in config? ${EasyPermissions.isEnabled("camera")}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final status = await EasyPermissions.askPermission('camera');
                debugPrint('Camera Status: $status');
              },
              child: const Text('Ask Camera'),
            ),
            const SizedBox(height: 10),
             ElevatedButton(
              onPressed: () async {
                final results = await EasyPermissions.ask();
                debugPrint('All Results: $results');
              },
              child: const Text('Ask All Enabled'),
            ),
             const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                 // Microphone is set to false in config
                 await EasyPermissions.askPermission('microphone');
              },
              child: const Text('Ask Microphone (Disabled)'),
            ),
          ],
        )),
      ),
    );
  }
}
