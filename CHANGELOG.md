## 0.0.4

- Upgrade permission_handler to 13.0.2 and support current XML and lint packages.
- Preserve published PermissionStatus return types; add detailed results for platform support and permanent denial.
- Normalize and copy configuration, reject ambiguous keys, and clear stale configuration after invalid JSON loading.
- Preserve exact typed native permissions, background-location opt-in, and storage/photo distinctions.
- Aggregate Android Bluetooth scan/connect for the string API and fail gracefully on unsupported platforms or backend errors.
- Fix native setup cleanup of whitespace-separated plist values and shared permission declarations.
- Validate native XML before writing, return failing exit codes, and retain dry-run/idempotent setup behavior.
- Replace the stale example test, add runtime/web/CLI regression tests, and modernize native example builds.
- Require Dart 3.11+ and Flutter 3.24+ to match current dependency requirements.

## 0.0.3

* **Bug fix**: `notifications` web-unsupported check now correctly matches the `'notifications'` JSON key (was `'notification'` — would have caused web crashes).
* **New**: `EasyPermissions.initFromString(String json)` — initialize from a raw JSON string, useful for remote config and unit tests.
* **New**: `EasyPermissions.reset()` — clears loaded config; makes unit testing clean.
* **New**: `EasyPermissions.openSettings()` — convenience wrapper around `openAppSettings()` for permanently-denied flows.
* **New**: `locationAlways` config key — requests background location (`ACCESS_BACKGROUND_LOCATION` on Android, `NSLocationAlwaysAndWhenInUseUsageDescription` on iOS).
* **Setup tool — new flags**:
  * `--dry-run` — preview changes without writing any files.
  * `--remove-unused` — remove disabled permissions from `AndroidManifest.xml` and `Info.plist`.
  * `--config <path>` — point to a custom JSON config path.
  * `--verbose` — log every permission, even unchanged ones.
  * `--help` — print usage.
* **Setup tool**: Added `ACCESS_COARSE_LOCATION` alongside `ACCESS_FINE_LOCATION` for `location`.
* **Setup tool**: Added `READ_EXTERNAL_STORAGE` alongside `READ_MEDIA_IMAGES` for `photos` (Android < 13 support).
* **Setup tool**: Added `phone` and `sensors` to permission mappings.
* **Setup tool**: Removed legacy `BLUETOOTH` / `BLUETOOTH_ADMIN` in favour of `BLUETOOTH_SCAN` + `BLUETOOTH_CONNECT`.
* **Setup tool**: iOS `notifications` entry is no longer silently skipped — it correctly has no plist key (handled at runtime) and logs an informational message in `--verbose` mode.
* **Removed** unused `args` dependency.



* Updated `permission_handler`, `args`, `path`, and `xml` dependencies to latest stable versions.
* Added type-safe API `EasyPermissions.request(Permission permission)` and `EasyPermissions.check(Permission permission)`.

## 0.0.1

* Initial release of EasyPermissions.
* Supports JSON-based configuration.
* Automated Android Manifest and iOS Info.plist setup.
* Support for Camera, Location, Microphone, Photos, Contacts, Notifications, and Bluetooth.
* Built-in error handling for Web.
