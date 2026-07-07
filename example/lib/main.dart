import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
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
  Map<String, PermissionResult> _statuses = {};
  final Set<String> _loadingKeys = {};
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
    setState(() {
      _loadingKeys.add(key);
    });
    await EasyPermissions.askPermission(key);
    await _refreshStatuses();
    setState(() {
      _loadingKeys.remove(key);
    });
  }

  Future<void> _askAll() async {
    await EasyPermissions.ask();
    _refreshStatuses();
  }

  Future<void> _openSettings() async {
    final success = await EasyPermissions.openSettings();
    if (!success && mounted) {
      // Fallback for Web/Desktop
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Action Required"),
          content: const Text(
            "Automatic settings navigation is not supported on this platform.\n\n"
            "Please manually grant the permission by clicking the lock icon in your URL bar or checking your system preferences.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
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
                      result: _statuses[key]!,
                      isLoading: _loadingKeys.contains(key),
                      onAsk: () => _askPermission(key),
                      onOpenSettings: _openSettings,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
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
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 55,
                          child: OutlinedButton.icon(
                            onPressed: _openSettings,
                            icon: const Icon(Icons.settings_rounded),
                            label: const Text(
                              "Open Settings",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              side: const BorderSide(
                                color: Color(0xFF0072FF),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
  final PermissionResult result;
  final bool isLoading;
  final VoidCallback onAsk;
  final VoidCallback onOpenSettings;

  const PermissionCard({
    super.key,
    required this.keyName,
    required this.result,
    required this.isLoading,
    required this.onAsk,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final isGranted = result.status.isGranted;
    final isPermanentlyDenied = result.isPermanentlyDenied;
    final isSupported = result.isSupported;
    final isEnabledInConfig = EasyPermissions.isEnabled(keyName);

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (!isEnabledInConfig) {
      statusColor = Colors.grey.shade500;
      statusIcon = Icons.block_rounded;
      statusText = "Disabled in Config";
    } else if (!isSupported) {
      statusColor = Colors.grey.shade500;
      statusIcon = Icons.do_not_disturb_alt_rounded;
      statusText = "Not Supported";
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
      statusText = "Ask";
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
            if (isLoading)
              const Padding(
                padding: EdgeInsets.only(right: 12.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (isEnabledInConfig && isSupported && !isGranted)
              isPermanentlyDenied
                  ? FutureBuilder<bool>(
                      future: _canOpenSettings(),
                      builder: (context, snapshot) {
                        final canOpen = snapshot.data ?? true;
                        return canOpen
                            ? TextButton(
                                onPressed: onOpenSettings,
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red.shade600,
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                child: const Text("Open Settings"),
                              )
                            : const SizedBox.shrink();
                      },
                    )
                  : TextButton(
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

  Future<bool> _canOpenSettings() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      // On desktop, we might still try but warn the user
      return true;
    }
    return true;
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
