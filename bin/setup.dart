import 'dart:io';
import 'dart:convert';
import 'package:xml/xml.dart';
import 'package:path/path.dart' as p;
import 'package:easy_permissions_manager/src/configuration.dart';

// ignore_for_file: avoid_print

// ─── Permission mappings ──────────────────────────────────────────────────────
//
// 'android' : String | List<String>  — <uses-permission android:name="…"> values
// 'ios_key' : String | null          — Info.plist usage description key
// 'ios_msg' : String | null          — Default iOS usage description text
//
const Map<String, Map<String, dynamic>> permissionMappings = {
  'camera': {
    'android': 'android.permission.CAMERA',
    'ios_key': 'NSCameraUsageDescription',
    'ios_msg': 'This app needs access to the camera.',
  },
  'location': {
    'android': [
      'android.permission.ACCESS_FINE_LOCATION',
      'android.permission.ACCESS_COARSE_LOCATION',
    ],
    'ios_key': 'NSLocationWhenInUseUsageDescription',
    'ios_msg': 'This app needs access to your location.',
  },
  // Always-on background location — use only when the app genuinely needs it.
  'locationalways': {
    'android': [
      'android.permission.ACCESS_FINE_LOCATION',
      'android.permission.ACCESS_COARSE_LOCATION',
      'android.permission.ACCESS_BACKGROUND_LOCATION',
    ],
    'ios_key': 'NSLocationAlwaysAndWhenInUseUsageDescription',
    'ios_msg': 'This app needs access to your location at all times.',
    // Also inject the WhenInUse key, required alongside AlwaysAndWhenInUse.
    'ios_extra_key': 'NSLocationWhenInUseUsageDescription',
    'ios_extra_msg': 'This app needs access to your location.',
  },
  'microphone': {
    'android': 'android.permission.RECORD_AUDIO',
    'ios_key': 'NSMicrophoneUsageDescription',
    'ios_msg': 'This app needs access to the microphone.',
  },
  'photos': {
    // READ_MEDIA_IMAGES is for Android 13+; READ_EXTERNAL_STORAGE covers older.
    'android': [
      'android.permission.READ_MEDIA_IMAGES',
      'android.permission.READ_EXTERNAL_STORAGE',
    ],
    'ios_key': 'NSPhotoLibraryUsageDescription',
    'ios_msg': 'This app needs access to your photo library.',
  },
  'storage': {
    'android': [
      'android.permission.READ_EXTERNAL_STORAGE',
      'android.permission.WRITE_EXTERNAL_STORAGE',
    ],
    'ios_key': null, // Storage is not a separate permission on iOS.
    'ios_msg': null,
  },
  'contacts': {
    'android': 'android.permission.READ_CONTACTS',
    'ios_key': 'NSContactsUsageDescription',
    'ios_msg': 'This app needs access to your contacts.',
  },
  'notifications': {
    'android': 'android.permission.POST_NOTIFICATIONS',
    // iOS notifications do not use an Info.plist usage description key;
    // they are requested at runtime via UNUserNotificationCenter.
    'ios_key': null,
    'ios_msg': null,
  },
  'bluetooth': {
    'android': [
      'android.permission.BLUETOOTH',
      'android.permission.BLUETOOTH_ADMIN',
      'android.permission.BLUETOOTH_SCAN',
      'android.permission.BLUETOOTH_CONNECT',
    ],
    'ios_key': 'NSBluetoothAlwaysUsageDescription',
    'ios_msg': 'This app needs access to Bluetooth.',
  },
  'phone': {
    'android': 'android.permission.READ_PHONE_STATE',
    'ios_key': null,
    'ios_msg': null,
  },
  'sensors': {
    'android': 'android.permission.BODY_SENSORS',
    'ios_key': 'NSMotionUsageDescription',
    'ios_msg': 'This app needs access to motion and fitness data.',
  },
};

// ─── Entry point ─────────────────────────────────────────────────────────────

void main(List<String> rawArgs) async {
  // Parse flags manually to avoid the `args` dependency.
  final bool dryRun = rawArgs.contains('--dry-run');
  final bool removeUnused = rawArgs.contains('--remove-unused');
  final bool verbose = rawArgs.contains('--verbose');

  String configPath = 'assets/easy_permissions.json';
  for (int i = 0; i < rawArgs.length; i++) {
    if (rawArgs[i] == '--config' && i + 1 < rawArgs.length) {
      configPath = rawArgs[i + 1];
    }
    if (rawArgs[i].startsWith('--config=')) {
      configPath = rawArgs[i].substring('--config='.length);
    }
  }

  if (rawArgs.contains('--help') || rawArgs.contains('-h')) {
    _printHelp();
    exit(0);
  }

  for (int i = 0; i < rawArgs.length; i++) {
    final arg = rawArgs[i];
    if (arg == '--config') {
      if (++i >= rawArgs.length || rawArgs[i].startsWith('--')) {
        logError('--config requires a file path.');
        return;
      }
      continue;
    }
    if (arg.startsWith('--config=') && arg.substring(9).isNotEmpty) continue;
    if (!['--dry-run', '--remove-unused', '--verbose'].contains(arg)) {
      logError('Unknown option: $arg');
      return;
    }
  }

  logInfo('🚀 Starting Easy Permissions Setup...');
  if (dryRun) logInfo('   (dry-run mode — no files will be written)');

  final configFile = File(configPath);
  if (!configFile.existsSync()) {
    logError('Configuration file not found at $configPath');
    exit(1);
  }

  Map<String, dynamic> config;
  try {
    config = normalizeConfig(
      Map<String, dynamic>.from(
        json.decode(configFile.readAsStringSync()) as Map,
      ),
    );
  } catch (e) {
    logError('Failed to parse $configPath: $e');
    exit(1);
  }

  for (final entry in {
    p.join('android', 'app', 'src', 'main', 'AndroidManifest.xml'): 'manifest',
    p.join('ios', 'Runner', 'Info.plist'): 'dict',
  }.entries) {
    final file = File(entry.key);
    if (!file.existsSync()) continue;
    try {
      final document = XmlDocument.parse(file.readAsStringSync());
      if (document.findAllElements(entry.value).isEmpty) {
        throw FormatException('Missing <${entry.value}>');
      }
    } catch (e) {
      logError('Invalid ${entry.key}: $e');
      return;
    }
  }

  await _processAndroid(
    config,
    dryRun: dryRun,
    removeUnused: removeUnused,
    verbose: verbose,
  );
  await _processIOS(
    config,
    dryRun: dryRun,
    removeUnused: removeUnused,
    verbose: verbose,
  );

  logInfo(
    dryRun
        ? '✅ Dry-run complete. No files were changed.'
        : '✅ Easy Permissions Setup Complete!',
  );
}

// ─── Android ─────────────────────────────────────────────────────────────────

Future<void> _processAndroid(
  Map<String, dynamic> config, {
  required bool dryRun,
  required bool removeUnused,
  required bool verbose,
}) async {
  final manifestPath = p.join(
    'android',
    'app',
    'src',
    'main',
    'AndroidManifest.xml',
  );
  final file = File(manifestPath);
  if (!file.existsSync()) {
    logWarning('AndroidManifest.xml not found at $manifestPath — skipping.');
    return;
  }

  logInfo('Processing AndroidManifest.xml…');

  XmlDocument document;
  try {
    document = XmlDocument.parse(file.readAsStringSync());
  } catch (e) {
    logError('Failed to parse AndroidManifest.xml: $e');
    return;
  }

  final manifestNode = document.findAllElements('manifest').firstOrNull;
  if (manifestNode == null) {
    logError('No <manifest> tag found in AndroidManifest.xml');
    return;
  }

  bool modified = false;

  // ── Add required permissions ──────────────────────────────────────────────
  config.forEach((key, value) {
    if (!_isEnabled(value)) return;

    final mapping = permissionMappings[key];
    if (mapping == null) {
      if (verbose) logWarning('No mapping found for config key "$key".');
      return;
    }

    final perms = _androidPerms(mapping);
    for (final perm in perms) {
      final exists = _androidPermExists(manifestNode, perm);
      if (!exists) {
        logInfo('  ➕ Adding: $perm');
        if (!dryRun) {
          final builder = XmlBuilder();
          builder.element(
            'uses-permission',
            attributes: {
              'android:name': perm,
              if (_maxSdk(perm) != null)
                'android:maxSdkVersion': _maxSdk(perm)!,
            },
          );
          manifestNode.children.add(builder.buildFragment());
          modified = true;
        }
      } else if (verbose) {
        logInfo('  ✓  Already present: $perm');
      }
    }
  });

  final requiredAndroid = config.entries
      .where((e) => _isEnabled(e.value))
      .expand((e) => _androidPerms(permissionMappings[e.key] ?? {}))
      .toSet();

  // ── Warn / remove disabled permissions ───────────────────────────────────
  config.forEach((key, value) {
    if (_isEnabled(value)) return;

    final mapping = permissionMappings[key];
    if (mapping == null) return;

    final perms = _androidPerms(mapping);
    for (final perm in perms) {
      if (requiredAndroid.contains(perm)) continue;
      if (!_androidPermExists(manifestNode, perm)) continue;

      if (removeUnused) {
        logInfo('  🗑  Removing unused permission (--remove-unused): $perm');
        if (!dryRun) {
          manifestNode.children.removeWhere(
            (node) =>
                node is XmlElement &&
                node.name.local == 'uses-permission' &&
                node.getAttribute('android:name') == perm,
          );
          modified = true;
        }
      } else {
        logWarningBold(
          '⚠️  Unused permission: $perm is in AndroidManifest.xml '
          'but disabled in JSON. Run with --remove-unused to clean it up.',
        );
      }
    }
  });

  if (modified && !dryRun) {
    file.writeAsStringSync(document.toXmlString(pretty: true, indent: '    '));
    logInfo('✅ AndroidManifest.xml updated.');
  } else if (!modified) {
    logInfo('   No changes needed for AndroidManifest.xml.');
  }
}

// ─── iOS ─────────────────────────────────────────────────────────────────────

Future<void> _processIOS(
  Map<String, dynamic> config, {
  required bool dryRun,
  required bool removeUnused,
  required bool verbose,
}) async {
  final plistPath = p.join('ios', 'Runner', 'Info.plist');
  final file = File(plistPath);
  if (!file.existsSync()) {
    logWarning('Info.plist not found at $plistPath — skipping.');
    return;
  }

  logInfo('Processing ios/Runner/Info.plist…');

  XmlDocument document;
  try {
    document = XmlDocument.parse(file.readAsStringSync());
  } catch (e) {
    logError('Failed to parse Info.plist: $e');
    return;
  }

  final dict = document.findAllElements('dict').firstOrNull;
  if (dict == null) {
    logError('No root <dict> tag found in Info.plist');
    return;
  }

  bool modified = false;

  // ── Add required keys ─────────────────────────────────────────────────────
  config.forEach((key, value) {
    if (!_isEnabled(value)) return;

    final mapping = permissionMappings[key];
    if (mapping == null) {
      if (verbose) logWarning('No mapping found for config key "$key".');
      return;
    }

    final iosKey = mapping['ios_key'] as String?;
    if (iosKey == null) {
      if (verbose) {
        logInfo('  ℹ️  "$key" has no Info.plist entry (handled at runtime).');
      }
      return;
    }

    final customDesc = _customDescription(value);
    final iosMsg = customDesc ?? mapping['ios_msg'] as String;

    modified =
        _addPlistKeyIfMissing(
          dict,
          iosKey,
          iosMsg,
          dryRun: dryRun,
          verbose: verbose,
        ) ||
        modified;

    // Handle extra iOS key (e.g. locationAlways also needs WhenInUse key).
    final extraKey = mapping['ios_extra_key'] as String?;
    final extraMsg = mapping['ios_extra_msg'] as String?;
    if (extraKey != null && extraMsg != null) {
      modified =
          _addPlistKeyIfMissing(
            dict,
            extraKey,
            extraMsg,
            dryRun: dryRun,
            verbose: verbose,
          ) ||
          modified;
    }
  });

  final requiredIOS = <String>{};
  for (final entry in config.entries.where((e) => _isEnabled(e.value))) {
    final mapping = permissionMappings[entry.key];
    for (final name in ['ios_key', 'ios_extra_key']) {
      final key = mapping?[name] as String?;
      if (key != null) requiredIOS.add(key);
    }
  }

  // ── Warn / remove disabled keys ───────────────────────────────────────────
  config.forEach((key, value) {
    if (_isEnabled(value)) return;

    final mapping = permissionMappings[key];
    if (mapping == null) return;

    final iosKey = mapping['ios_key'] as String?;
    if (iosKey == null) return;

    if (requiredIOS.contains(iosKey) || !_plistKeyExists(dict, iosKey)) return;

    if (removeUnused) {
      logInfo('  🗑  Removing unused iOS key (--remove-unused): $iosKey');
      if (!dryRun) {
        _removePlistKey(dict, iosKey);
        modified = true;
      }
    } else {
      logWarningBold(
        '⚠️  Unused iOS key: $iosKey exists in Info.plist but "$key" '
        'is disabled in JSON. Run with --remove-unused to clean it up.',
      );
    }
  });

  if (modified && !dryRun) {
    file.writeAsStringSync(document.toXmlString(pretty: true, indent: '\t'));
    logInfo('✅ Info.plist updated.');
  } else if (!modified) {
    logInfo('   No changes needed for Info.plist.');
  }
}

// ─── Plist helpers ────────────────────────────────────────────────────────────

bool _addPlistKeyIfMissing(
  XmlElement dict,
  String iosKey,
  String iosMsg, {
  required bool dryRun,
  required bool verbose,
}) {
  if (_plistKeyExists(dict, iosKey)) {
    if (verbose) logInfo('  ✓  Already present: $iosKey');
    return false;
  }

  logInfo('  ➕ Adding: $iosKey  →  "$iosMsg"');
  if (!dryRun) {
    final builder = XmlBuilder();
    builder.element('key', nest: () => builder.text(iosKey));
    builder.element('string', nest: () => builder.text(iosMsg));
    dict.children.add(builder.buildFragment());
  }
  return true;
}

bool _plistKeyExists(XmlElement dict, String iosKey) {
  return dict.children.whereType<XmlElement>().any(
    (e) => e.name.local == 'key' && e.innerText == iosKey,
  );
}

void _removePlistKey(XmlElement dict, String iosKey) {
  final children = dict.children;
  for (int i = children.length - 1; i >= 0; i--) {
    final child = children[i];
    if (child is XmlElement &&
        child.name.local == 'key' &&
        child.innerText == iosKey) {
      // Remove the <key> node and its following <string> sibling.
      children.removeAt(i);
      final next = children.skip(i).whereType<XmlElement>().firstOrNull;
      if (next != null && next.name.local != 'key') children.remove(next);
      break;
    }
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

bool _isEnabled(dynamic value) => enabledValue(value);

String? _customDescription(dynamic value) {
  if (value is String && value.isNotEmpty) return value;
  if (value is Map) return value['description'] as String?;
  return null;
}

List<String> _androidPerms(Map<String, dynamic> mapping) {
  final raw = mapping['android'];
  if (raw is String) return [raw];
  if (raw is List) return raw.cast<String>();
  return [];
}

String? _maxSdk(String permission) => switch (permission) {
  'android.permission.READ_EXTERNAL_STORAGE' => '32',
  'android.permission.WRITE_EXTERNAL_STORAGE' => '28',
  'android.permission.BLUETOOTH' ||
  'android.permission.BLUETOOTH_ADMIN' => '30',
  _ => null,
};

bool _androidPermExists(XmlElement manifestNode, String perm) {
  return manifestNode
      .findElements('uses-permission')
      .any((n) => n.getAttribute('android:name') == perm);
}

// ─── Logging ──────────────────────────────────────────────────────────────────

void logInfo(String msg) => print(msg);

void logError(String msg) {
  exitCode = 1;
  print('\x1B[31m❌ [Error] $msg\x1B[0m');
}

void logWarning(String msg) => print('\x1B[33m⚠️  [Warning] $msg\x1B[0m');

void logWarningBold(String msg) => print('\x1B[1;33m$msg\x1B[0m');

// ─── Help ─────────────────────────────────────────────────────────────────────

void _printHelp() {
  print('''
Easy Permissions Manager — Setup Tool

USAGE
  dart run easy_permissions_manager:setup [options]

OPTIONS
  --config <path>    Path to the JSON config file.
                     Default: assets/easy_permissions.json

  --dry-run          Show what would be changed without writing any files.
                     Useful for CI checks.

  --remove-unused    Remove <uses-permission> and Info.plist keys for
                     permissions that are disabled in the JSON config.

  --verbose          Print a line for every permission, even unchanged ones.

  -h, --help         Show this help message.

EXAMPLES
  dart run easy_permissions_manager:setup
  dart run easy_permissions_manager:setup --dry-run
  dart run easy_permissions_manager:setup --remove-unused
  dart run easy_permissions_manager:setup --config assets/my_permissions.json
''');
}
