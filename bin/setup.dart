import 'dart:io';
import 'dart:convert';
import 'package:xml/xml.dart';
import 'package:path/path.dart' as p;

// ignore_for_file: avoid_print

const Map<String, Map<String, dynamic>> permissionMappings = {
  'camera': {
    'android': 'android.permission.CAMERA',
    'ios_key': 'NSCameraUsageDescription',
    'ios_msg': 'This app needs access to the camera.',
  },
  'location': {
    'android':
        'android.permission.ACCESS_FINE_LOCATION', // Defaulting to fine, maybe add coarse too
    'ios_key': 'NSLocationWhenInUseUsageDescription',
    'ios_msg': 'This app needs access to location when in use.',
  },
  'microphone': {
    'android': 'android.permission.RECORD_AUDIO',
    'ios_key': 'NSMicrophoneUsageDescription',
    'ios_msg': 'This app needs access to the microphone.',
  },
  'photos': {
    'android': 'android.permission.READ_MEDIA_IMAGES', // Modern Android
    'ios_key': 'NSPhotoLibraryUsageDescription',
    'ios_msg': 'This app needs access to your photos.',
  },
  'contacts': {
    'android': 'android.permission.READ_CONTACTS',
    'ios_key': 'NSContactsUsageDescription',
    'ios_msg': 'This app needs access to your contacts.',
  },
  'notifications': {
    'android': 'android.permission.POST_NOTIFICATIONS',
    'ios_key':
        'N/A', // iOS notifications are largely code-based, but could use UNUserNotificationCenter
    'ios_msg': 'N/A',
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
};

void main(List<String> args) async {
  print('🚀 Starting Easy Permissions Setup...');

  final configFile = File('assets/easy_permissions.json');
  if (!configFile.existsSync()) {
    logError('Configuration file not found at assets/easy_permissions.json');
    exit(1);
  }

  Map<String, dynamic> config;
  try {
    final jsonString = configFile.readAsStringSync();
    config = json.decode(jsonString);
  } catch (e) {
    logError('Failed to parse easy_permissions.json: $e');
    exit(1);
  }

  // 1. Process Android
  await _processAndroid(config);

  // 2. Process iOS
  await _processIOS(config);

  print('✅ Easy Permissions Setup Complete! Run "flutter pub get" if needed.');
}

Future<void> _processAndroid(Map<String, dynamic> config) async {
  final manifestPath = p.join(
    'android',
    'app',
    'src',
    'main',
    'AndroidManifest.xml',
  );
  final file = File(manifestPath);
  if (!file.existsSync()) {
    logWarning('AndroidManifest.xml not found at $manifestPath');
    return;
  }

  print('Processing AndroidManifest.xml...');
  String content = file.readAsStringSync();
  XmlDocument document;
  try {
    document = XmlDocument.parse(content);
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

  config.forEach((key, value) {
    bool isEnabled = false;
    if (value == true) {
      isEnabled = true;
    } else if (value is String && value.isNotEmpty) {
      isEnabled = true;
    } else if (value is Map && value['required'] == true) {
      isEnabled = true;
    }

    if (isEnabled) {
      final mapping = permissionMappings[key];
      if (mapping != null && mapping['android'] != null) {
        final rawAndroid = mapping['android'];
        List<String> androidPerms = [];
        if (rawAndroid is String) {
          androidPerms.add(rawAndroid);
        } else if (rawAndroid is List) {
          androidPerms.addAll(rawAndroid.cast<String>());
        }

        for (final androidPerm in androidPerms) {
          // Check if exists
          bool exists = manifestNode.findElements('uses-permission').any((
            node,
          ) {
            return node.getAttribute('android:name') == androidPerm;
          });

          if (!exists) {
            print('➕ Adding Android Permission: $androidPerm');
            final builder = XmlBuilder();
            builder.element(
              'uses-permission',
              attributes: {'android:name': androidPerm},
            );
            manifestNode.children.add(builder.buildFragment());
            modified = true;
          }
        }
      }
    } else if (value == false || (value is Map && value['required'] != true)) {
      // Check for unused permission
      final mapping = permissionMappings[key];
      if (mapping != null && mapping['android'] != null) {
        final rawAndroid = mapping['android'];
        List<String> androidPerms = [];
        if (rawAndroid is String) {
          androidPerms.add(rawAndroid);
        } else if (rawAndroid is List) {
          androidPerms.addAll(rawAndroid.cast<String>());
        }

        for (final androidPerm in androidPerms) {
          bool exists = manifestNode.findElements('uses-permission').any((
            node,
          ) {
            return node.getAttribute('android:name') == androidPerm;
          });
          if (exists) {
            logWarningBold(
              'Unused Permission Detected! $androidPerm exists in AndroidManifest.xml but is set to false in JSON.',
            );
          }
        }
      }
    }
  });

  if (modified) {
    file.writeAsStringSync(document.toXmlString(pretty: true, indent: '    '));
    print('✅ AndroidManifest.xml updated.');
  } else {
    print('No changes needed for AndroidManifest.xml.');
  }
}

Future<void> _processIOS(Map<String, dynamic> config) async {
  final plistPath = p.join('ios', 'Runner', 'Info.plist');
  final file = File(plistPath);
  if (!file.existsSync()) {
    logWarning('Info.plist not found at $plistPath');
    return;
  }

  print('Processing Info.plist...');
  String content = file.readAsStringSync();

  // Plist is messy to parse with XML package because it's key-value pairs in a dict.
  // We can treat it as text or try to parse carefully.
  // Using XML is safer.
  XmlDocument document;
  try {
    document = XmlDocument.parse(content);
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

  config.forEach((key, value) {
    bool isEnabled = false;
    String? customDesc;

    if (value == true) {
      isEnabled = true;
    } else if (value is String && value.isNotEmpty) {
      isEnabled = true;
      customDesc = value;
    } else if (value is Map && value['required'] == true) {
      isEnabled = true;
      customDesc = value['description'];
    }

    if (isEnabled) {
      final mapping = permissionMappings[key];
      if (mapping != null &&
          mapping['ios_key'] != null &&
          mapping['ios_key'] != 'N/A') {
        final iosKey = mapping['ios_key']!;
        // Use custom string if available, otherwise default
        final iosMsg = customDesc ?? mapping['ios_msg']!;

        // Check if key exists in the dict
        // The structure is <key>Name</key><string>Value</string>
        bool exists = false;
        final children = dict.children;

        for (int i = 0; i < children.length; i++) {
          if (children[i] is XmlElement &&
              (children[i] as XmlElement).name.local == 'key') {
            if ((children[i] as XmlElement).innerText == iosKey) {
              exists = true;
              break;
            }
          }
        }

        if (!exists) {
          print('➕ Adding iOS Key: $iosKey with description: "$iosMsg"');
          // We need to add <key>...</key> and <string>...</string>
          // XML builder
          final builder = XmlBuilder();
          builder.element('key', nest: () => builder.text(iosKey));
          builder.element('string', nest: () => builder.text(iosMsg));

          // Add to end of dict
          dict.children.add(builder.buildFragment());
          modified = true;
        } else {
          // Optional: Update description if it differs?
          // Not strictly requested but nice to have.
          // Finding the value node (next sibling usually) is hard with just XML iteration if there are whitespaces.
          // Let's stick to "Add missing".
        }
      }
    } else {
      // Check for unused
      final mapping = permissionMappings[key];
      if (mapping != null &&
          mapping['ios_key'] != null &&
          mapping['ios_key'] != 'N/A') {
        final iosKey = mapping['ios_key']!;
        bool exists = false;
        final children = dict.children;
        for (int i = 0; i < children.length; i++) {
          if (children[i] is XmlElement &&
              (children[i] as XmlElement).name.local == 'key') {
            if ((children[i] as XmlElement).innerText == iosKey) {
              exists = true;
              break;
            }
          }
        }
        if (exists) {
          logWarningBold(
            'Unused Permission Detected! $iosKey exists in Info.plist but is set to false in JSON.',
          );
        }
      }
    }
  });

  if (modified) {
    file.writeAsStringSync(document.toXmlString(pretty: true, indent: '\t'));
    print('✅ Info.plist updated.');
  } else {
    print('No changes needed for Info.plist.');
  }
}

void logError(String msg) {
  print('\x1B[31m❌ [Error] $msg\x1B[0m');
}

void logWarning(String msg) {
  print('\x1B[33m⚠️ [Warning] $msg\x1B[0m');
}

void logWarningBold(String msg) {
  // Bold Red
  print('\x1B[1;31m⚠️  $msg\x1B[0m');
}
