import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'network_bound_http_android_platform_interface.dart';

/// An implementation of [NetworkBoundHttpAndroidPlatform] that uses method channels.
class MethodChannelNetworkBoundHttpAndroid extends NetworkBoundHttpAndroidPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('network_bound_http_android');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
