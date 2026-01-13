import 'package:flutter_test/flutter_test.dart';
import 'package:network_bound_http_android/network_bound_http_android.dart';
import 'package:network_bound_http_android/network_bound_http_android_platform_interface.dart';
import 'package:network_bound_http_android/network_bound_http_android_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockNetworkBoundHttpAndroidPlatform
    with MockPlatformInterfaceMixin
    implements NetworkBoundHttpAndroidPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final NetworkBoundHttpAndroidPlatform initialPlatform = NetworkBoundHttpAndroidPlatform.instance;

  test('$MethodChannelNetworkBoundHttpAndroid is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelNetworkBoundHttpAndroid>());
  });

  test('getPlatformVersion', () async {
    NetworkBoundHttpAndroid networkBoundHttpAndroidPlugin = NetworkBoundHttpAndroid();
    MockNetworkBoundHttpAndroidPlatform fakePlatform = MockNetworkBoundHttpAndroidPlatform();
    NetworkBoundHttpAndroidPlatform.instance = fakePlatform;

    expect(await networkBoundHttpAndroidPlugin.getPlatformVersion(), '42');
  });
}
