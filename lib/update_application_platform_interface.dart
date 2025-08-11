import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'update_application_method_channel.dart';

abstract class UpdateApplicationPlatform extends PlatformInterface {
  /// Constructs a UpdateAppPlatform.
  UpdateApplicationPlatform() : super(token: _token);

  static final Object _token = Object();

  static UpdateApplicationPlatform _instance = MethodChannelUpdateApplication();

  /// The default instance of [UpdateApplicationPlatform] to use.
  ///
  /// Defaults to [MethodChannelUpdateApplication].
  static UpdateApplicationPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [UpdateApplicationPlatform] when
  /// they register themselves.
  static set instance(UpdateApplicationPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
