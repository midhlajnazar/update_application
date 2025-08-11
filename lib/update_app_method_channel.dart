import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'update_app_platform_interface.dart';

/// An implementation of [UpdateAppPlatform] that uses method channels.
class MethodChannelUpdateApp extends UpdateAppPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('update_app');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
