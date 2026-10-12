import 'package:flutter_test/flutter_test.dart';
import 'package:easy_permissions_manager/easy_permissions_manager.dart';
import 'package:example/main.dart';

void main() {
  testWidgets('permission dashboard loads without the obsolete counter UI', (
    tester,
  ) async {
    EasyPermissions.reset();
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.text('Easy Permissions'), findsOneWidget);
    expect(find.text('Your Permissions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
