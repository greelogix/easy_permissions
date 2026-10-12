# Easy Permissions Manager example

Use current stable Flutter for native builds. The package requires Dart 3.11+.

```sh
flutter pub get
dart run easy_permissions_manager:setup --dry-run
dart run easy_permissions_manager:setup
flutter analyze
flutter test
flutter run
```

The dashboard uses the additive detailed API to show unsupported permissions.
Android uses the current Flutter native Gradle template. iOS uses Swift Package Manager.
Permission grants and denial prompts require a physical device or suitable browser.

Android example: API 37.0 compilation, minimum Android API 24.
iOS example: iOS 15 or later.
