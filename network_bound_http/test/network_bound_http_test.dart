import 'package:flutter_test/flutter_test.dart';
import 'package:network_bound_http/network_bound_http.dart';
import 'package:network_bound_http/network_bound_http_platform_interface.dart';
import 'package:network_bound_http/network_bound_http_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockNetworkBoundHttpPlatform
    with MockPlatformInterfaceMixin
    implements NetworkBoundHttpPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final NetworkBoundHttpPlatform initialPlatform = NetworkBoundHttpPlatform.instance;

  test('$MethodChannelNetworkBoundHttp is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelNetworkBoundHttp>());
  });

  test('getPlatformVersion', () async {
    NetworkBoundHttp networkBoundHttpPlugin = NetworkBoundHttp();
    MockNetworkBoundHttpPlatform fakePlatform = MockNetworkBoundHttpPlatform();
    NetworkBoundHttpPlatform.instance = fakePlatform;

    expect(await networkBoundHttpPlugin.getPlatformVersion(), '42');
  });
}
