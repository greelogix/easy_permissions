import 'package:flutter/material.dart';
import 'package:easy_permissions_manager/easy_permissions_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
          seedColor: const Color(0xFF00C6FF),
          brightness: Brightness.light,
          primary: const Color(0xFF00C6FF),
          secondary: const Color(0xFF0072FF),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 12,
          backgroundColor: Colors.white,
          titleTextStyle: TextStyle(
            color: Colors.black87,
            fontFamily: 'GoogleSans',
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
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
      appBar: AppBar(title: const Text("Easy Permissions")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshStatuses,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                children: [
                  const GradientHeader(
                    icon: Icons.shield_rounded,
                    title:
                        "Control app permissions easily with EasyPermissions",
                    gradient: LinearGradient(
                      colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Your Permissions",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._statuses.keys.map(
                    (key) => PermissionCard(
                      keyName: key,
                      status: _statuses[key]!,
                      onAsk: () => _askPermission(key),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: FilledButton.icon(
                      onPressed: _askAll,
                      icon: const Icon(Icons.playlist_add_check_rounded),
                      label: const Text(
                        "Request All",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor: const Color(0xFF0072FF),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class GradientHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Gradient gradient;

  const GradientHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 40, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,

              textAlign: TextAlign.start,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PermissionCard extends StatelessWidget {
  final String keyName;
  final PermissionStatus status;
  final VoidCallback onAsk;

  const PermissionCard({
    super.key,
    required this.keyName,
    required this.status,
    required this.onAsk,
  });

  @override
  Widget build(BuildContext context) {
    final isGranted = status.isGranted;
    final isPermanentlyDenied = status.isPermanentlyDenied;
    final isEnabledInConfig = EasyPermissions.isEnabled(keyName);

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (!isEnabledInConfig) {
      statusColor = Colors.grey.shade500;
      statusIcon = Icons.block_rounded;
      statusText = "Disabled in Config";
    } else if (isGranted) {
      statusColor = Colors.green.shade600;
      statusIcon = Icons.check_circle_rounded;
      statusText = "Granted";
    } else if (isPermanentlyDenied) {
      statusColor = Colors.red.shade600;
      statusIcon = Icons.cancel_rounded;
      statusText = "Denied Forever";
    } else {
      statusColor = Colors.orange.shade600;
      statusIcon = Icons.info_rounded;
      statusText = "Not Granted";
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shadowColor: Colors.black.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getIconForKey(keyName),
                color: statusColor,
                size: 16,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _capitalize(keyName),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isEnabledInConfig && !isGranted)
              TextButton(
                onPressed: onAsk,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF0072FF),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
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
        return Icons.camera_alt_rounded;
      case 'location':
        return Icons.location_on_rounded;
      case 'microphone':
        return Icons.mic_rounded;
      case 'photos':
        return Icons.photo_library_rounded;
      case 'contacts':
        return Icons.contacts_rounded;
      case 'notifications':
        return Icons.notifications_active_rounded;
      default:
        return Icons.security_rounded;
    }
  }

  String _capitalize(String s) => s[0].toUpperCase() + s.substring(1);
}
