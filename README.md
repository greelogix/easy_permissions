# Easy Permissions Manager for Flutter

[![pub package](https://img.shields.io/pub/v/easy_permissions_manager.svg)](https://pub.dev/packages/easy_permissions_manager)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A robust, JSON-based permission manager for Flutter that simplifies permission handling across Android, iOS, and Web.
**Easy Permissions Manager** automates the tedious setup of `AndroidManifest.xml` and `Info.plist`, handles run-time requests, and provides a smart API to check and request permissions.

---

## 🚀 Features

*   **JSON Configuration**: Manage all permissions in a single `easy_permissions.json` file.
*   **Automated Setup**: One command to update Android Manifest and iOS Info.plist automatically.
*   **Smart UI**: Includes helper methods to check if permissions are granted, denied, or permanently denied.
*   **Web Support**: Gracefully handles permission checks on Web (silencing unsupported API errors).
*   **Dependent on Permission Handler**: Exports `permission_handler` so you don't need to add it separately.
*   **Supports**: Camera, Location, Microphone, Photos, Contacts, Notifications, Bluetooth.

---

## 📦 Installation

1.  Add `easy_permissions_manager` to your `pubspec.yaml`:

    ```yaml
    dependencies:
      easy_permissions_manager: ^0.0.1
    ```

2.  Run `flutter pub get`.

---

## 🛠 Setup

### 1. Create Configuration File
Create a file named `easy_permissions.json` in your `assets` folder (e.g., `assets/easy_permissions.json`).

```json
{
  "camera": {
    "required": true,
    "description": "We need access to your camera for profile photos."
  },
  "location": {
    "required": true,
    "description": "Location is required for finding nearby stores."
  },
  "microphone": true,
  "photos": false,
  "contacts": true,
  "notifications": true,
  "bluetooth": {
    "required": true,
    "description": "Bluetooth is needed to connect to accessories."
  }
}
```

### 2. Register Asset
Ensure the asset is registered in your `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/easy_permissions.json
```

### 3. Run Setup Tool
Run the built-in setup command to automatically configure your native files. This will add the necessary `<uses-permission>` tags to `AndroidManifest.xml` and Usage Description keys to `Info.plist`.

```bash
dart run easy_permissions_manager:setup
```

> **Note**: You must run this command whenever you change your `easy_permissions.json` file.

---

## 💻 Usage

### Initialization
Initialize the library in your `main()` method.

```dart
import 'package:easy_permissions_manager/easy_permissions_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // load configuration
  await EasyPermissions.initFromAsset('assets/easy_permissions.json');
  
  runApp(const MyApp());
}
```

### Requesting Permissions
You can request a single permission or all enabled permissions at once.

```dart
// Request a specific permission
PermissionStatus status = await EasyPermissions.askPermission('camera');

if (status.isGranted) {
  // open camera
}

// Request ALL permissions defined in your config
Map<String, PermissionStatus> results = await EasyPermissions.ask();
```

### Checking Status
Check the status of permissions without asking.

```dart
// Check single
PermissionStatus status = await EasyPermissions.checkPermission('location');

// Check all
Map<String, PermissionStatus> statuses = await EasyPermissions.checkStatus();
```

---

## 🌐 Web Support
Permissions on the Web are handled differently than mobile. `easy_permissions_manager` automatically detects if the app is running on Web and:
*   Silences errors for unsupported permissions (like `contacts` or `bluetooth`) by returning `PermissionStatus.denied` instead of crashing.
*   Allows supported permissions (like `camera` and `microphone`) to work normally.

---

## 📝 Configuration Options
The JSON configuration supports simple booleans or detailed objects.

| Type | Example | Description |
|---|---|---|
| **Boolean** | `"microphone": true` | Enables permission. Uses default system messages for iOS. |
| **String** | `"camera": "Access required"` | Enables permission and uses the string as the iOS usage description. |
| **Object** | see below | provides `required` (bool) and `description` (string). |

**Object Example:**
```json
"bluetooth": {
  "required": true,
  "description": "We need Bluetooth to connect to the device."
}
```

---

## ❤️ Contributing
Contributions are welcome! If you find a bug or want a feature, please open an issue.

maintained by [GreeLogix](https://github.com/greelogix).
