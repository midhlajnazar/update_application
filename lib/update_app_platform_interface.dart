import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'update_app_method_channel.dart';

abstract class UpdateAppPlatform extends PlatformInterface {
  /// Constructs a UpdateAppPlatform.
  UpdateAppPlatform() : super(token: _token);

  static final Object _token = Object();

  static UpdateAppPlatform _instance = MethodChannelUpdateApp();

  /// The default instance of [UpdateAppPlatform] to use.
  ///
  /// Defaults to [MethodChannelUpdateApp].
  static UpdateAppPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [UpdateAppPlatform] when
  /// they register themselves.
  static set instance(UpdateAppPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
