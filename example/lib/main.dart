import 'package:flutter/material.dart';
import 'package:easy_permissions/easy_permissions.dart';
// ignore: depend_on_referenced_packages
import 'package:permission_handler/permission_handler.dart';

// ignore_for_file: deprecated_member_use

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize with Dart Map, or load from JSON asset if preferred
  // await EasyPermissions.initFromAsset('assets/easy_permissions.json');
  // For this demo, we'll assume the JSON asset is loaded by the logic or we init here:
  await EasyPermissions.initFromAsset('assets/easy_permissions.json');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'GoogleSans',
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF), // Modern Indigo/Purple
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          titleTextStyle: TextStyle(
            color: Colors.black87,
            fontFamily: 'GoogleSans',
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      home: const PermissionDashboard(),
    );
  }
}

class PermissionDashboard extends StatefulWidget {
  const PermissionDashboard({super.key});

  @override
  State<PermissionDashboard> createState() => _PermissionDashboardState();
}

class _PermissionDashboardState extends State<PermissionDashboard> {
  Map<String, PermissionStatus> _statuses = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refreshStatuses();
  }

  Future<void> _refreshStatuses() async {
    // Check status of all managed permissions
    final results = await EasyPermissions.checkStatus();
    setState(() {
      _statuses = results;
      _loading = false;
    });
  }

  Future<void> _askPermission(String key) async {
    await EasyPermissions.askPermission(key);
    _refreshStatuses();
  }

  Future<void> _askAll() async {
    await EasyPermissions.ask();
    _refreshStatuses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // Light grey bg
      appBar: AppBar(title: const Text("Easy Permissions")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshStatuses,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  const Text(
                    "Managed Permissions",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._statuses.keys.map(
                    (key) => _buildPermissionCard(key, _statuses[key]!),
                  ),

                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _askAll,
                      icon: const Icon(Icons.playlist_add_check),
                      label: const Text(
                        "Request All Enabled",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(
            Icons.shield_moon_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            "Manage your app permissions properly with EasyPermissions.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard(String key, PermissionStatus status) {
    final bool isGranted = status.isGranted;
    final bool isPermanentlyDenied = status.isPermanentlyDenied;
    final bool isEnabledInConfig = EasyPermissions.isEnabled(key);

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (!isEnabledInConfig) {
      statusColor = Colors.grey;
      statusIcon = Icons.block;
      statusText = "Disabled in Config";
    } else if (isGranted) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = "Granted";
    } else if (isPermanentlyDenied) {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
      statusText = "Denied Forever";
    } else {
      statusColor = Colors.orange;
      statusIcon = Icons.info;
      statusText = "Not Granted";
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(_getIconForKey(key), color: statusColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _capitalize(key),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isEnabledInConfig && !isGranted)
              TextButton(
                onPressed: () => _askPermission(key),
                child: const Text("Ask"),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForKey(String key) {
    switch (key.toLowerCase()) {
      case 'camera':
        return Icons.camera_alt;
      case 'location':
        return Icons.location_on;
      case 'microphone':
        return Icons.mic;
      case 'photos':
        return Icons.photo;
      case 'contacts':
        return Icons.contacts;
      case 'notifications':
        return Icons.notifications;
      case 'bluetooth':
        return Icons.bluetooth;
      default:
        return Icons.security;
    }
  }

  String _capitalize(String s) => s[0].toUpperCase() + s.substring(1);
}
