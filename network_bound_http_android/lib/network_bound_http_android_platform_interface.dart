import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'network_bound_http_android_method_channel.dart';

abstract class NetworkBoundHttpAndroidPlatform extends PlatformInterface {
  /// Constructs a NetworkBoundHttpAndroidPlatform.
  NetworkBoundHttpAndroidPlatform() : super(token: _token);

  static final Object _token = Object();

  static NetworkBoundHttpAndroidPlatform _instance = MethodChannelNetworkBoundHttpAndroid();

  /// The default instance of [NetworkBoundHttpAndroidPlatform] to use.
  ///
  /// Defaults to [MethodChannelNetworkBoundHttpAndroid].
  static NetworkBoundHttpAndroidPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [NetworkBoundHttpAndroidPlatform] when
  /// they register themselves.
  static set instance(NetworkBoundHttpAndroidPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
