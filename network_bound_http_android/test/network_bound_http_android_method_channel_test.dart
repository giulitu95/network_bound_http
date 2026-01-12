import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_bound_http_android/network_bound_http_android_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelNetworkBoundHttpAndroid platform = MethodChannelNetworkBoundHttpAndroid();
  const MethodChannel channel = MethodChannel('network_bound_http_android');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
