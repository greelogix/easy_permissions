import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

void main() {
  late Directory project;
  late File manifest;
  late File plist;
  final script = p.join(Directory.current.path, 'bin', 'setup.dart');
  final packages = p.join(
    Directory.current.path,
    '.dart_tool',
    'package_config.json',
  );
  final packageConfig = jsonDecode(File(packages).readAsStringSync()) as Map;
  final flutterPackage = (packageConfig['packages'] as List)
      .cast<Map>()
      .firstWhere((entry) => entry['name'] == 'flutter');
  final flutterRoot = Uri.file(
    packages,
  ).resolve(flutterPackage['rootUri'] as String).resolve('../');
  final dartExecutable = flutterRoot
      .resolve('bin/cache/dart-sdk/bin/dart')
      .toFilePath();
  Future<ProcessResult> run([List<String> args = const []]) => Process.run(
    dartExecutable,
    ['--packages=$packages', script, ...args],
    workingDirectory: project.path,
  );
  void config(Map<String, dynamic> value) => File(
    p.join(project.path, 'assets', 'easy_permissions.json'),
  ).writeAsStringSync(jsonEncode(value));
  setUp(() {
    project = Directory.systemTemp.createTempSync('easy-permissions-test-');
    manifest = File(
      p.join(
        project.path,
        'android',
        'app',
        'src',
        'main',
        'AndroidManifest.xml',
      ),
    )..createSync(recursive: true);
    manifest.writeAsStringSync(
      '<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application /></manifest>',
    );
    plist = File(p.join(project.path, 'ios', 'Runner', 'Info.plist'))
      ..createSync(recursive: true);
    plist.writeAsStringSync(
      '<?xml version="1.0"?><plist version="1.0"><dict><key>CFBundleName</key><string>Demo</string></dict></plist>',
    );
    Directory(p.join(project.path, 'assets')).createSync();
  });
  tearDown(() => project.deleteSync(recursive: true));
  test('setup adds permissions and is idempotent', () async {
    config({'CAMERA': 'Use camera & photos', 'locationAlways': true});
    expect((await run()).exitCode, 0);
    final before = [manifest.readAsStringSync(), plist.readAsStringSync()];
    expect(before.first, contains('ACCESS_BACKGROUND_LOCATION'));
    expect(
      before.last,
      contains('NSLocationAlwaysAndWhenInUseUsageDescription'),
    );
    expect(
      XmlDocument.parse(
        before.last,
      ).findAllElements('string').map((e) => e.innerText),
      contains('Use camera & photos'),
    );
    expect((await run()).exitCode, 0);
    expect([manifest.readAsStringSync(), plist.readAsStringSync()], before);
  });
  test('dry run never changes native files', () async {
    config({'camera': true});
    final before = [manifest.readAsStringSync(), plist.readAsStringSync()];
    expect((await run(['--dry-run'])).exitCode, 0);
    expect([manifest.readAsStringSync(), plist.readAsStringSync()], before);
  });
  test(
    'remove-unused handles whitespace and preserves shared location keys',
    () async {
      config({'camera': true, 'location': true, 'locationAlways': true});
      await run();
      config({'camera': false, 'location': false, 'locationAlways': true});
      expect((await run(['--remove-unused'])).exitCode, 0);
      final doc = XmlDocument.parse(plist.readAsStringSync());
      expect(
        doc.findAllElements('key').map((e) => e.innerText),
        isNot(contains('NSCameraUsageDescription')),
      );
      expect(
        doc.findAllElements('string').map((e) => e.innerText),
        isNot(contains('This app needs access to the camera.')),
      );
      expect(
        doc.findAllElements('key').map((e) => e.innerText),
        contains('NSLocationWhenInUseUsageDescription'),
      );
      expect(manifest.readAsStringSync(), contains('ACCESS_FINE_LOCATION'));
    },
  );
  test('invalid native XML fails before writing either file', () async {
    config({'camera': true});
    plist.writeAsStringSync('<invalid');
    final before = manifest.readAsStringSync();
    expect((await run()).exitCode, isNot(0));
    expect(manifest.readAsStringSync(), before);
  });
  test('invalid configuration returns a failing exit status', () async {
    File(
      p.join(project.path, 'assets', 'easy_permissions.json'),
    ).writeAsStringSync('[]');
    expect((await run()).exitCode, isNot(0));
  });
}
