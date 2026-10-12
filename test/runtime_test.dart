import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_permissions_manager/easy_permissions_manager.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart'
    as platform;

class _Handler extends platform.PermissionHandlerPlatform {
  final requested = <Permission>[];
  final checked = <Permission>[];
  PermissionStatus result = PermissionStatus.granted;
  bool fail = false;
  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async {
    if (fail) throw StateError('Backend unavailable');
    requested.addAll(permissions);
    return {for (final permission in permissions) permission: result};
  }

  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) async {
    if (fail) throw StateError('Backend unavailable');
    checked.add(permission);
    return result;
  }

  @override
  Future<bool> openAppSettings() async {
    if (fail) throw StateError('No settings');
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Handler handler;
  late platform.PermissionHandlerPlatform original;
  setUp(() {
    original = platform.PermissionHandlerPlatform.instance;
    handler = _Handler();
    platform.PermissionHandlerPlatform.instance = handler;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    EasyPermissions.reset();
  });
  tearDown(() {
    platform.PermissionHandlerPlatform.instance = original;
    debugDefaultTargetPlatformOverride = null;
    EasyPermissions.reset();
  });
  test('configuration is copied and keys are case insensitive', () {
    final camera = <String, dynamic>{'required': true};
    final config = <String, dynamic>{
      ' Camera ': camera,
      'microphone': '   ',
      'location': false,
    };
    EasyPermissions.init(config);
    camera['required'] = false;
    config.clear();
    expect(EasyPermissions.isEnabled('CAMERA'), isTrue);
    expect(EasyPermissions.isEnabled('microphone'), isFalse);
  });
  test('ambiguous normalized keys are rejected', () {
    expect(
      () => EasyPermissions.init({'camera': true, 'CAMERA': false}),
      throwsFormatException,
    );
  });
  test('JSON initialization and reset retain the published API', () {
    EasyPermissions.initFromString('{"camera":true}');
    expect(EasyPermissions.isEnabled('camera'), isTrue);
    EasyPermissions.initFromString('[]');
    expect(EasyPermissions.isEnabled('camera'), isFalse);
    EasyPermissions.reset();
    expect(EasyPermissions.isEnabled('camera'), isFalse);
  });
  test('requests only configured enabled permissions', () async {
    EasyPermissions.init({'camera': true, 'microphone': false});
    final PermissionStatus result = await EasyPermissions.request(
      Permission.camera,
    );
    expect(result, PermissionStatus.granted);
    expect(
      await EasyPermissions.askPermission('microphone'),
      PermissionStatus.denied,
    );
    expect(
      await EasyPermissions.askPermission('missing'),
      PermissionStatus.denied,
    );
    expect(handler.requested, [Permission.camera]);
  });
  test('status checks never request permissions', () async {
    EasyPermissions.init({'camera': true});
    final Map<String, PermissionStatus> statuses =
        await EasyPermissions.checkStatus();
    expect(statuses['camera'], PermissionStatus.granted);
    expect(handler.requested, isEmpty);
    expect(handler.checked, [Permission.camera]);
  });
  test(
    'all-permission requests keep published status-map return types',
    () async {
      EasyPermissions.init({'camera': true, 'microphone': true});
      final Map<String, PermissionStatus> results = await EasyPermissions.ask();
      expect(results.values, everyElement(PermissionStatus.granted));
      expect(handler.requested, [Permission.camera, Permission.microphone]);
    },
  );
  test(
    'background location needs explicit enablement and keeps its native type',
    () async {
      EasyPermissions.init({'location': true});
      expect(
        await EasyPermissions.request(Permission.locationAlways),
        PermissionStatus.denied,
      );
      expect(handler.requested, isEmpty);
      EasyPermissions.init({'locationAlways': true});
      expect(
        await EasyPermissions.request(Permission.locationAlways),
        PermissionStatus.granted,
      );
      expect(handler.requested, [Permission.locationAlways]);
    },
    skip: kIsWeb,
  );
  test(
    'storage and Bluetooth variants are not redirected to another permission',
    () async {
      EasyPermissions.init({'storage': true, 'bluetooth': true});
      await EasyPermissions.askPermission('storage');
      await EasyPermissions.request(Permission.bluetoothScan);
      expect(handler.requested, [Permission.storage, Permission.bluetoothScan]);
    },
    skip: kIsWeb,
  );
  test('string Bluetooth requests modern scan and connect together', () async {
    EasyPermissions.init({'bluetooth': true});
    expect(
      await EasyPermissions.askPermission('bluetooth'),
      PermissionStatus.granted,
    );
    expect(handler.requested, [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ]);
    handler.result = PermissionStatus.permanentlyDenied;
    expect(
      await EasyPermissions.checkPermission('bluetooth'),
      PermissionStatus.permanentlyDenied,
    );
  }, skip: kIsWeb);

  test('detailed API distinguishes unsupported permissions', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    EasyPermissions.init({'camera': true});
    final result = await EasyPermissions.requestDetailed(Permission.camera);
    expect(result.isSupported, isFalse);
    expect(handler.requested, isEmpty);
  }, skip: kIsWeb);
  test('permanent denial is preserved by both APIs', () async {
    handler.result = PermissionStatus.permanentlyDenied;
    EasyPermissions.init({'camera': true});
    final result = await EasyPermissions.requestDetailed(Permission.camera);
    expect(result.isPermanentlyDenied, isTrue);
    expect(result.isSupported, isTrue);
    expect(
      await EasyPermissions.request(Permission.camera),
      PermissionStatus.permanentlyDenied,
    );
  });
  test('backend failures return denied without crashing', () async {
    handler.fail = true;
    EasyPermissions.init({'camera': true});
    expect(
      await EasyPermissions.request(Permission.camera),
      PermissionStatus.denied,
    );
    expect(
      await EasyPermissions.checkPermission('camera'),
      PermissionStatus.denied,
    );
    expect(await EasyPermissions.openSettings(), isFalse);
  });
  test(
    'web rejects unsupported permissions without invoking the backend',
    () async {
      EasyPermissions.init({
        'contacts': true,
        'notifications': true,
        'locationAlways': true,
      });
      final statuses = await EasyPermissions.ask();
      expect(statuses.values, everyElement(PermissionStatus.denied));
      expect(handler.requested, isEmpty);
    },
    skip: !kIsWeb,
  );
}
