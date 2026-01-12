import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'network_bound_http_method_channel.dart';

abstract class NetworkBoundHttpPlatform extends PlatformInterface {
  /// Constructs a NetworkBoundHttpPlatform.
  NetworkBoundHttpPlatform() : super(token: _token);

  static final Object _token = Object();

  static NetworkBoundHttpPlatform _instance = MethodChannelNetworkBoundHttp();

  /// The default instance of [NetworkBoundHttpPlatform] to use.
  ///
  /// Defaults to [MethodChannelNetworkBoundHttp].
  static NetworkBoundHttpPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [NetworkBoundHttpPlatform] when
  /// they register themselves.
  static set instance(NetworkBoundHttpPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
