## 0.0.3

* Added `PermissionResult` class that includes both status and permanently denied information.
* Added `EasyPermissions.openSettings()` method to open app settings.
* Improved Bluetooth permission handling.
* Added support for more permissions: Reminders, Calendar, Speech, Ignore Battery Optimizations, etc.
* Updated `xml` dependency to ^7.0.0.
* Improved web support - only unsupported permissions are marked as denied.

## 0.0.2

* Updated `permission_handler`, `args`, `path`, and `xml` dependencies to latest stable versions.
* Added type-safe API `EasyPermissions.request(Permission permission)` and `EasyPermissions.check(Permission permission)`.

## 0.0.1

* Initial release of EasyPermissions.
* Supports JSON-based configuration.
* Automated Android Manifest and iOS Info.plist setup.
* Support for Camera, Location, Microphone, Photos, Contacts, Notifications, and Bluetooth.
* Built-in error handling for Web.
