library;

import 'dart:typed_data';

import 'package:network_bound_http_platform_interface/types.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'channel_network_bound_http.dart';

/// The interface that implementations of danfoss_api_wrapper must implement.
abstract class NetworkBoundHttpPlatform extends PlatformInterface {
  NetworkBoundHttpPlatform() : super(token: _token);

  static final Object _token = Object();

  static NetworkBoundHttpPlatform  _instance = ChannelNetworkBoundHttp();

  /// The default instance of [DanfossApiWrapperPlatform] to use.
  /// Defaults to [ChannelDanfossApiWrapper].
  static NetworkBoundHttpPlatform get instance => _instance;

  /// Platform-specific plugins should set this with their own platform-specific
  /// class that extends [DanfossApiWrapperPlatform] when they
  /// register themselves.
  static set instance(NetworkBoundHttpPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }


  Stream<NetworkBoundHttpEvent> sendHttpRequest({
    required String uri,
    required String method,
    required String outputPath,
    Map<String, String>? headers,
    Uint8List? body,
    Duration? timeout,
    NetworkType network,
  });
}
