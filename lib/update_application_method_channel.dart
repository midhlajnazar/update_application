import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'update_application_platform_interface.dart';

/// An implementation of [UpdateApplicationPlatform] that uses method channels.
class MethodChannelUpdateApplication extends UpdateApplicationPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('update_application');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
