import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'channel_network_bound_http.dart';

/// The interface that implementations of network_bound_http must implement.
abstract class NetworkBoundHttpPlatform extends PlatformInterface {
  NetworkBoundHttpPlatform() : super(token: _token);

  static final Object _token = Object();

  static NetworkBoundHttpPlatform _instance = ChannelNetworkBoundHttp();

  /// The default instance of [NetworkBoundHttpPlatform] to use.
  /// Defaults to [ChannelNetworkBoundHttp].
  static NetworkBoundHttpPlatform get instance => _instance;

  /// Platform-specific plugins should set this with their own platform-specific
  /// class that extends [NetworkBoundHttpPlatform] when they
  /// register themselves.
  static set instance(NetworkBoundHttpPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Stream<Map<String, dynamic>> get callbackStream;

  Future<String?> sendRequest({required Map<String, dynamic> request});
}
