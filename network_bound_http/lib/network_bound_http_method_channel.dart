import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'network_bound_http_platform_interface.dart';

/// An implementation of [NetworkBoundHttpPlatform] that uses method channels.
class MethodChannelNetworkBoundHttp extends NetworkBoundHttpPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('network_bound_http');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
