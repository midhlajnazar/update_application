import 'package:flutter_test/flutter_test.dart';
import 'package:update_app/update_app.dart';
import 'package:update_app/update_app_platform_interface.dart';
import 'package:update_app/update_app_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockUpdateAppPlatform
    with MockPlatformInterfaceMixin
    implements UpdateAppPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final UpdateAppPlatform initialPlatform = UpdateAppPlatform.instance;

  test('$MethodChannelUpdateApp is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelUpdateApp>());
  });

  test('getPlatformVersion', () async {
    UpdateApp updateAppPlugin = UpdateApp();
    MockUpdateAppPlatform fakePlatform = MockUpdateAppPlatform();
    UpdateAppPlatform.instance = fakePlatform;

    // expect(await updateAppPlugin.getPlatformVersion(), '42');
  });
}
