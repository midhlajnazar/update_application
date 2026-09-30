## 0.0.4

- Added Swift Package Manager support for iOS (`ios/update_application/Package.swift`); CocoaPods remains supported.
- Moved iOS sources to `ios/update_application/Sources/update_application/` and updated the podspec accordingly.
- **Breaking:** raised the minimum iOS deployment target from 12.0 to 15.0 (plugin and example app).
- Enabled the iOS privacy manifest (`PrivacyInfo.xcprivacy`) as a bundled resource for both SPM and CocoaPods.

## 0.0.3

- Upgraded Android build configuration to Java 17 (`sourceCompatibility` and `targetCompatibility`).
- Bumped minimum Flutter SDK constraint to `>=3.16.0`.
- Fixed Android plugin `AppUpdateManager` initialization and event listener registration bug.

## 0.0.2

- Minor updates and code formating.


## 0.0.1

- Initial release with Android and iOS update support.
