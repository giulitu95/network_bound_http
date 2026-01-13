
import 'dart:typed_data';

import 'package:network_bound_http_platform_interface/channel_network_bound_http.dart';
import 'package:network_bound_http_platform_interface/network_bound_http_platform_interface.dart';
import 'package:network_bound_http_platform_interface/types.dart';


class NetworkBoundHttpAndroid extends NetworkBoundHttpPlatform {
  NetworkBoundHttpAndroid() : super();

  /// During registration, set instance as default
  static void registerWith() {
    NetworkBoundHttpPlatform.instance = NetworkBoundHttpAndroid();
  }

  @override
  Stream<NetworkBoundHttpEvent> sendHttpRequest({
    required String uri,
    String method = "GET",
    Map<String, String>? headers,
    Uint8List? body,
    Duration? timeout,
    NetworkType? network,
  }) {
    return ChannelNetworkBoundHttp().sendHttpRequest(
      uri: uri,
      method: method,
      headers: headers,
      body: body,
      timeout: timeout,
      network: network,
    );
  }
}
