import 'package:flutter_test/flutter_test.dart';
import 'package:update_application/update_application.dart';
import 'package:update_application/update_application_platform_interface.dart';
import 'package:update_application/update_application_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockUpdateApplicationPlatform
    with MockPlatformInterfaceMixin
    implements UpdateApplicationPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final UpdateApplicationPlatform initialPlatform =
      UpdateApplicationPlatform.instance;

  test('$MethodChannelUpdateApplication is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelUpdateApplication>());
  });

  test('getPlatformVersion', () async {
    UpdateApplication UpdateApplicationPlugin = UpdateApplication();
    MockUpdateApplicationPlatform fakePlatform =
        MockUpdateApplicationPlatform();
    UpdateApplicationPlatform.instance = fakePlatform;

    // expect(await UpdateApplicationPlugin.getPlatformVersion(), '42');
  });
}
