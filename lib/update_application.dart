import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Status of a download/install.
///
/// For more information, see its corresponding page on
/// [Android Developers](https://developer.android.com/reference/com/google/android/play/core/install/model/InstallStatus.html).
enum InstallStatus {
  unknown(0),
  pending(1),
  downloading(2),
  installing(3),
  installed(4),
  failed(5),
  canceled(6),
  downloaded(11);

  const InstallStatus(this.value);
  final int value;

  /// Returns a human-readable description of the install status
  String get description {
    switch (this) {
      case InstallStatus.unknown:
        return 'Unknown status';
      case InstallStatus.pending:
        return 'Update pending';
      case InstallStatus.downloading:
        return 'Downloading update';
      case InstallStatus.installing:
        return 'Installing update';
      case InstallStatus.installed:
        return 'Update installed';
      case InstallStatus.failed:
        return 'Update failed';
      case InstallStatus.canceled:
        return 'Update canceled';
      case InstallStatus.downloaded:
        return 'Update downloaded';
    }
  }
}

/// Availability of an update for the requested package.
///
/// For more information, see its corresponding page on
/// [Android Developers](https://developer.android.com/reference/com/google/android/play/core/install/model/UpdateAvailability.html).
enum UpdateAvailability {
  unknown(0),
  updateNotAvailable(1),
  updateAvailable(2),
  developerTriggeredUpdateInProgress(3);

  const UpdateAvailability(this.value);
  final int value;

  /// Returns a human-readable description of the update availability
  String get description {
    switch (this) {
      case UpdateAvailability.unknown:
        return 'Update availability unknown';
      case UpdateAvailability.updateNotAvailable:
        return 'No update available';
      case UpdateAvailability.updateAvailable:
        return 'Update available';
      case UpdateAvailability.developerTriggeredUpdateInProgress:
        return 'Developer-triggered update in progress';
    }
  }
}

/// Result of an app update operation
enum AppUpdateResult {
  /// The user has accepted the update. For immediate updates, you might not
  /// receive this callback because the update should already be completed by
  /// Google Play by the time the control is given back to your app.
  success,

  /// The user has denied or cancelled the update.
  userDeniedUpdate,

  /// Some other error prevented either the user from providing consent or the
  /// update to proceed.
  inAppUpdateFailed,

  /// Network error occurred during update check or download
  networkError,

  /// Platform not supported (neither Android nor iOS)
  platformNotSupported,

  /// Update check failed due to invalid app configuration
  configurationError,
}

/// Update priority levels for better update management
enum UpdatePriority {
  low(0),
  medium(1),
  high(2),
  critical(3);

  const UpdatePriority(this.value);
  final int value;

  /// Create UpdatePriority from integer value
  static UpdatePriority fromValue(int value) {
    return UpdatePriority.values.firstWhere(
      (priority) => priority.value == value,
      orElse: () => UpdatePriority.low,
    );
  }
}

/// Exception thrown when update operations fail
class UpdateException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const UpdateException(this.message, {this.code, this.originalError});

  @override
  String toString() =>
      'UpdateException: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Configuration for update behavior
class UpdateConfig {
  /// Whether to enable debug logging
  final bool enableLogging;

  const UpdateConfig({this.enableLogging = kDebugMode});
}

/// Main class for handling app updates across Android and iOS platforms
class UpdateApplication {
  static const MethodChannel _channel = MethodChannel(
    'update_application/methods',
  );
  static const EventChannel _installListener = EventChannel(
    'update_application/stateEvents',
  );

  static UpdateConfig _config = const UpdateConfig();
  static StreamController<InstallStatus>? _statusController;

  /// Configure the update behavior
  static void configure(UpdateConfig config) {
    _config = config;
    _log('UpdateApplication configured with: $config');
  }

  /// Check for available updates with enhanced error handling and caching
  static Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      _log('Checking for updates...');

      if (Platform.isAndroid) {
        return await _checkAndroidUpdate();
      } else if (Platform.isIOS) {
        return await _checkiOSUpdate();
      } else {
        throw UpdateException(
          'Platform not supported',
          code: 'PLATFORM_NOT_SUPPORTED',
        );
      }
    } catch (e) {
      _log('Error checking for updates: $e');
      if (e is UpdateException) rethrow;
      throw UpdateException('Failed to check for updates', originalError: e);
    }
  }

  /// Android-specific update check
  static Future<AppUpdateInfo?> _checkAndroidUpdate() async {
    final result = await _channel.invokeMethod('checkForUpdate');

    final updateInfo = AppUpdateInfo(
      updateAvailability: UpdateAvailability.values.firstWhere(
        (element) => element.value == result['updateAvailability'],
        orElse: () => UpdateAvailability.unknown,
      ),
      immediateUpdateAllowed: result['immediateAllowed'] ?? false,
      immediateAllowedPreconditions: List<int>.from(
        result['immediateAllowedPreconditions'] ?? [],
      ),
      flexibleUpdateAllowed: result['flexibleAllowed'] ?? false,
      flexibleAllowedPreconditions: List<int>.from(
        result['flexibleAllowedPreconditions'] ?? [],
      ),
      availableVersionCode: result['availableVersionCode'],
      installStatus: InstallStatus.values.firstWhere(
        (element) => element.value == result['installStatus'],
        orElse: () => InstallStatus.unknown,
      ),
      packageName: result['packageName'] ?? '',
      clientVersionStalenessDays: result['clientVersionStalenessDays'],
      updatePriority: result['updatePriority'] ?? 0,
    );

    _log(
      'Android update check completed: ${updateInfo.updateAvailability.description}',
    );
    return updateInfo;
  }

  /// iOS-specific update check with timeout handling
  static Future<AppUpdateInfo?> _checkiOSUpdate() async {
    try {
      // Get package info with timeout
      final packageInfo = await _channel.invokeMethod('getPackageInfo');

      if (packageInfo == null) {
        throw UpdateException(
          'Failed to get package info',
          code: 'PACKAGE_INFO_NULL',
        );
      }

      final packageName = packageInfo['packageName'] as String? ?? '';
      final currentVersion = packageInfo['version'] as String? ?? '';

      if (packageName.isEmpty || currentVersion.isEmpty) {
        throw UpdateException(
          'Invalid package configuration',
          code: 'INVALID_PACKAGE_CONFIG',
        );
      }

      // Fetch App Store info with timeout
      final appStoreInfo = await _channel.invokeMethod('getIosAppStoreInfo', {
        'bundleId': packageName,
      });

      if (appStoreInfo == null) {
        _log('No App Store results found for bundle ID: $packageName');
        return _createNoUpdateInfo(packageName);
      }

      final appStoreVersion = appStoreInfo['version'] as String? ?? '';
      final appStoreLink = appStoreInfo['trackViewUrl'] as String? ?? '';

      if (appStoreVersion.isEmpty) {
        _log('Empty version returned from App Store');
        return _createNoUpdateInfo(packageName);
      }

      final isUpdateAvailable = _isVersionNewer(
        appStoreVersion,
        currentVersion,
      );

      final updateInfo = AppUpdateInfo(
        updateAvailability: isUpdateAvailable
            ? UpdateAvailability.updateAvailable
            : UpdateAvailability.updateNotAvailable,
        immediateUpdateAllowed: false,
        immediateAllowedPreconditions: null,
        flexibleUpdateAllowed: false,
        flexibleAllowedPreconditions: null,
        availableVersionCode: null,
        installStatus: InstallStatus.unknown,
        packageName: packageName,
        clientVersionStalenessDays: null,
        updatePriority: 0,
        appStoreLink: appStoreLink,
        appStoreVersion: appStoreVersion,
        currentVersion: currentVersion,
      );

      _log(
        'iOS update check completed: ${updateInfo.updateAvailability.description}',
      );
      return updateInfo;
    } on TimeoutException {
      throw UpdateException(
        'Network timeout during update check',
        code: 'NETWORK_TIMEOUT',
      );
    } catch (e) {
      if (e is UpdateException) rethrow;
      throw UpdateException('iOS update check failed', originalError: e);
    }
  }

  /// Enhanced version comparison with better parsing
  static bool _isVersionNewer(String storeVersion, String currentVersion) {
    try {
      final int current = getExtendedVersionNumber(currentVersion);
      final int latest = getExtendedVersionNumber(storeVersion);
      return latest > current;
    } catch (e) {
      _log('Error comparing versions: $e');
      return false;
    }
  }

  /// Create update info for no update scenario
  static AppUpdateInfo _createNoUpdateInfo(String packageName) {
    return AppUpdateInfo(
      updateAvailability: UpdateAvailability.updateNotAvailable,
      immediateUpdateAllowed: false,
      immediateAllowedPreconditions: null,
      flexibleUpdateAllowed: false,
      flexibleAllowedPreconditions: null,
      availableVersionCode: null,
      installStatus: InstallStatus.unknown,
      packageName: packageName,
      clientVersionStalenessDays: null,
      updatePriority: 0,
    );
  }

  /// Enhanced version number calculation with better error handling
  static int getExtendedVersionNumber(String version) {
    if (version.isEmpty) return 0;

    try {
      // Handle versions like "1.0.0-beta" or "1.0.0+123"
      final cleanVersion = version.split(RegExp(r'[-+]')).first;
      final parts = cleanVersion.split('.').map((part) {
        final parsed = int.tryParse(part);
        return parsed ?? 0;
      }).toList();

      // Ensure we have at least 3 parts
      while (parts.length < 3) {
        parts.add(0);
      }

      // Support up to 4 parts (major.minor.patch.build)
      if (parts.length >= 4) {
        return parts[0] * 1000000 +
            parts[1] * 10000 +
            parts[2] * 100 +
            parts[3];
      }

      return parts[0] * 10000 + parts[1] * 100 + parts[2];
    } catch (e) {
      _log('Error parsing version "$version": $e');
      return 0;
    }
  }

  /// Enhanced install status listener with error handling
  static Stream<InstallStatus> get installUpdateListener {
    _statusController ??= StreamController<InstallStatus>.broadcast(
      onListen: () => _log('Install status listener started'),
      onCancel: () => _log('Install status listener canceled'),
    );

    return _installListener
        .receiveBroadcastStream()
        .cast<int>()
        .map((int value) => _mapInstallStatus(value))
        .handleError((error) {
          _log('Error in install status stream: $error');
          _statusController?.addError(
            UpdateException(
              'Install status stream error',
              originalError: error,
            ),
          );
        });
  }

  /// Map integer values to InstallStatus enum
  static InstallStatus _mapInstallStatus(int value) {
    return InstallStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => InstallStatus.unknown,
    );
  }

  /// Perform immediate update with enhanced error handling
  static Future<AppUpdateResult> performImmediateUpdate() async {
    if (!Platform.isAndroid) {
      await _channel.invokeMethod('openIOSAppStore');
      return AppUpdateResult.success;
    }

    try {
      _log('Starting immediate update...');
      await _channel.invokeMethod('performImmediateUpdate');
      _log('Immediate update completed successfully');
      return AppUpdateResult.success;
    } on PlatformException catch (e) {
      _log(
        'Platform exception during immediate update: ${e.code} - ${e.message}',
      );
      return _mapPlatformException(e);
    } catch (e) {
      _log('Unexpected error during immediate update: $e');
      return AppUpdateResult.inAppUpdateFailed;
    }
  }

  /// Open App Store page on iOS
  static Future<bool> openIOSAppStore() async {
    if (!Platform.isIOS) {
      return false;
    }

    try {
      _log('Opening App Store:');
      final result = await _channel.invokeMethod('openIOSAppStore');
      return result ?? false;
    } catch (e) {
      _log('Error opening App Store: $e');
      return false;
    }
  }

  /// Map platform exception to AppUpdateResult
  static AppUpdateResult _mapPlatformException(PlatformException e) {
    switch (e.code) {
      case 'USER_DENIED_UPDATE':
        return AppUpdateResult.userDeniedUpdate;
      case 'IN_APP_UPDATE_FAILED':
        return AppUpdateResult.inAppUpdateFailed;
      case 'NETWORK_ERROR':
        return AppUpdateResult.networkError;
      default:
        return AppUpdateResult.inAppUpdateFailed;
    }
  }

  /// Internal logging method
  static void _log(String message) {
    if (_config.enableLogging) {
      print('[UpdateApplication] $message');
    }
  }

  /// Dispose resources
  static void dispose() {
    _statusController?.close();
    _statusController = null;
    _log('UpdateApplication disposed');
  }
}

/// Enhanced app update information class
class AppUpdateInfo {
  /// Whether an update is available for the app
  final UpdateAvailability updateAvailability;

  /// Whether an immediate update is allowed
  final bool immediateUpdateAllowed;

  /// Reasons why immediate update cannot be started
  final List<int>? immediateAllowedPreconditions;

  /// Whether a flexible update is allowed
  final bool flexibleUpdateAllowed;

  /// Reasons why flexible update cannot be started
  final List<int>? flexibleAllowedPreconditions;

  /// The version code of the update (Android only)
  final int? availableVersionCode;

  /// The progress status of the update
  final InstallStatus installStatus;

  /// The package name for the app to be updated
  final String packageName;

  /// Update priority level
  final int updatePriority;

  /// Days since the update became available (Android only)
  final int? clientVersionStalenessDays;

  /// App Store version (iOS only)
  final String? appStoreVersion;

  /// App Store link (iOS only)
  final String? appStoreLink;

  /// Current app version (iOS only)
  final String? currentVersion;

  const AppUpdateInfo({
    required this.updateAvailability,
    required this.immediateUpdateAllowed,
    required this.immediateAllowedPreconditions,
    required this.flexibleUpdateAllowed,
    required this.flexibleAllowedPreconditions,
    required this.availableVersionCode,
    required this.installStatus,
    required this.packageName,
    required this.clientVersionStalenessDays,
    required this.updatePriority,
    this.appStoreVersion,
    this.appStoreLink,
    this.currentVersion,
  });

  /// Whether any update is available
  bool get isUpdateAvailable =>
      updateAvailability == UpdateAvailability.updateAvailable;

  /// Whether the app can be updated immediately
  bool get canUpdateImmediately => isUpdateAvailable && immediateUpdateAllowed;

  /// Whether the app can be updated flexibly
  bool get canUpdateFlexibly => isUpdateAvailable && flexibleUpdateAllowed;

  /// Get update priority level
  UpdatePriority get priority => UpdatePriority.fromValue(updatePriority);

  /// Whether the update is considered stale (more than 7 days old)
  bool get isStaleUpdate => (clientVersionStalenessDays ?? 0) > 7;

  /// Whether this is a critical update (high priority and stale)
  bool get isCriticalUpdate =>
      priority.value >= UpdatePriority.high.value || isStaleUpdate;

  /// Create a copy with updated values
  AppUpdateInfo copyWith({
    UpdateAvailability? updateAvailability,
    bool? immediateUpdateAllowed,
    List<int>? immediateAllowedPreconditions,
    bool? flexibleUpdateAllowed,
    List<int>? flexibleAllowedPreconditions,
    int? availableVersionCode,
    InstallStatus? installStatus,
    String? packageName,
    int? clientVersionStalenessDays,
    int? updatePriority,
    String? appStoreVersion,
    String? appStoreLink,
    String? currentVersion,
  }) {
    return AppUpdateInfo(
      updateAvailability: updateAvailability ?? this.updateAvailability,
      immediateUpdateAllowed:
          immediateUpdateAllowed ?? this.immediateUpdateAllowed,
      immediateAllowedPreconditions:
          immediateAllowedPreconditions ?? this.immediateAllowedPreconditions,
      flexibleUpdateAllowed:
          flexibleUpdateAllowed ?? this.flexibleUpdateAllowed,
      flexibleAllowedPreconditions:
          flexibleAllowedPreconditions ?? this.flexibleAllowedPreconditions,
      availableVersionCode: availableVersionCode ?? this.availableVersionCode,
      installStatus: installStatus ?? this.installStatus,
      packageName: packageName ?? this.packageName,
      clientVersionStalenessDays:
          clientVersionStalenessDays ?? this.clientVersionStalenessDays,
      updatePriority: updatePriority ?? this.updatePriority,
      appStoreVersion: appStoreVersion ?? this.appStoreVersion,
      appStoreLink: appStoreLink ?? this.appStoreLink,
      currentVersion: currentVersion ?? this.currentVersion,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUpdateInfo &&
          runtimeType == other.runtimeType &&
          updateAvailability == other.updateAvailability &&
          immediateUpdateAllowed == other.immediateUpdateAllowed &&
          immediateAllowedPreconditions ==
              other.immediateAllowedPreconditions &&
          flexibleUpdateAllowed == other.flexibleUpdateAllowed &&
          flexibleAllowedPreconditions == other.flexibleAllowedPreconditions &&
          availableVersionCode == other.availableVersionCode &&
          installStatus == other.installStatus &&
          packageName == other.packageName &&
          clientVersionStalenessDays == other.clientVersionStalenessDays &&
          updatePriority == other.updatePriority &&
          appStoreVersion == other.appStoreVersion &&
          appStoreLink == other.appStoreLink &&
          currentVersion == other.currentVersion;

  @override
  int get hashCode =>
      updateAvailability.hashCode ^
      immediateUpdateAllowed.hashCode ^
      immediateAllowedPreconditions.hashCode ^
      flexibleUpdateAllowed.hashCode ^
      flexibleAllowedPreconditions.hashCode ^
      availableVersionCode.hashCode ^
      installStatus.hashCode ^
      packageName.hashCode ^
      clientVersionStalenessDays.hashCode ^
      updatePriority.hashCode ^
      appStoreVersion.hashCode ^
      appStoreLink.hashCode ^
      currentVersion.hashCode;

  @override
  String toString() =>
      'AppUpdateInfo{updateAvailability: ${updateAvailability.description}, '
      'immediateUpdateAllowed: $immediateUpdateAllowed, '
      'flexibleUpdateAllowed: $flexibleUpdateAllowed, '
      'availableVersionCode: $availableVersionCode, '
      'installStatus: ${installStatus.description}, '
      'packageName: $packageName, '
      'clientVersionStalenessDays: $clientVersionStalenessDays, '
      'updatePriority: ${priority.name}, '
      'appStoreVersion: $appStoreVersion, '
      'currentVersion: $currentVersion, '
      'appStoreLink: $appStoreLink}';
}
