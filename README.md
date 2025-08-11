
# UpdateApplication Flutter Plugin

A cross-platform Flutter plugin for checking, managing, and performing **in-app updates** on **Android** and **iOS**.
Supports Google Play **in-app updates** (immediate and flexible) and iOS **App Store version checks** with customizable update flows.

> **Note:** On Android, in-app updates work **only on production builds** installed from the **Google Play Store**. Debug or locally-installed APKs will not trigger update availability.


---

## ✨ Features

* **Cross-platform support** (Android & iOS)
* **Check for update availability**
* **Immediate updates** (Android)
* **Flexible updates** (Android)
* **App Store version checks** (iOS)
* **Automatic version comparison**
* **Install status listener**
* **Update priority levels**
* **Customizable logging**
* **Error handling with exceptions**

---

## 📦 Installation

Add the plugin to your `pubspec.yaml`:

```yaml
dependencies:
  update_application: ^0.0.1
```

Then run:

```sh
flutter pub get
```

---

## 🚀 Usage

### 1️⃣ Configure the Plugin (Optional)

```dart
import 'package:update_application/update_application.dart';

void main() {
  UpdateApplication.configure(UpdateConfig(enableLogging: true));
  runApp(MyApp());
}
```

---

### 2️⃣ Check for Updates

```dart
final updateInfo = await UpdateApplication.checkForUpdate();

if (updateInfo?.isUpdateAvailable ?? false) {
  print('Update available: ${updateInfo?.availableVersionCode}');
  
  if (updateInfo!.canUpdateImmediately) {
    await UpdateApplication.performImmediateUpdate();
  } else if (updateInfo.canUpdateFlexibly) {
    // Show your own prompt and handle flexible update
  }
} else {
  print('No updates available');
}
```

---

### 3️⃣ Listen for Install Status (Android Flexible Update)

```dart
UpdateApplication.installUpdateListener.listen((status) {
  print('Install status: ${status.description}');
});
```

---

### 4️⃣ Open iOS App Store

```dart
await UpdateApplication.openIOSAppStore();
```

---

## 📊 AppUpdateInfo Fields

| Field                        | Description                          |
| ---------------------------- | ------------------------------------ |
| `updateAvailability`         | Whether an update is available       |
| `immediateUpdateAllowed`     | Can start immediate update (Android) |
| `flexibleUpdateAllowed`      | Can start flexible update (Android)  |
| `availableVersionCode`       | New version code (Android)           |
| `installStatus`              | Current install/download status      |
| `packageName`                | App package/bundle ID                |
| `updatePriority`             | Update urgency (low → critical)      |
| `clientVersionStalenessDays` | Days since update became available   |
| `appStoreVersion`            | Latest App Store version (iOS)       |
| `appStoreLink`               | Link to App Store (iOS)              |
| `currentVersion`             | Installed app version (iOS)          |

---

## ⚠️ Platform Notes

### **Android**

* Uses **Google Play Core API** for in-app updates.
* Immediate updates will block the app until complete.
* Flexible updates allow user to continue using the app while downloading.

### **iOS**

* No native in-app update API.
* This plugin checks the App Store for a newer version and provides the link to open it.

---

## 🔍 Example Output

```plaintext
[UpdateApplication] Checking for updates...
[UpdateApplication] Android update check completed: Update available
[UpdateApplication] Starting immediate update...
[UpdateApplication] Immediate update completed successfully
```

---

## 🛠 Error Handling

All errors throw an `UpdateException` with:

* `message` – Description of the error
* `code` – Optional error code
* `originalError` – Platform-specific error

Example:

```dart
try {
    final AppUpdateInfo? info = await UpdateApplication.checkForUpdate();
    if (info == null) return;
    final isUpdateAvailable =  info.updateAvailability == UpdateAvailability.updateAvailable;
    if (isUpdateAvailable) {
        await UpdateApplication.performImmediateUpdate();
    }
} on UpdateException catch (e) {
  print('Update failed: $e');
}
```

---

## 📜 License

This project is licensed under the MIT License.

---

## 💡 Contributions

Feel free to fork, improve and contribute via PR.

---

## 🧑‍💼 Maintainer

**Midlaj Nazar**
[GitHub](https://github.com/midhlajnazar) | Dubai, UAE

```

Let me know if you want a downloadable `.md` file or need additional sections like **License**, **FAQ**, or **Troubleshooting**.
```
