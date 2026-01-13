library;

import 'dart:async';
import 'package:network_bound_http_platform_interface/network_bound_http_platform_interface.dart';
import 'package:network_bound_http_platform_interface/types.dart';
export 'package:network_bound_http_platform_interface/types.dart';

/// Facade API pubblica
class NetworkBoundHttp {
  NetworkBoundHttp._(); // costruttore privato

  /// Metodo principale: download di un file usando la rete specificata
  static Stream<NetworkBoundHttpEvent> download({
    required String url,
    required NetworkType network,
    int timeoutMs = 15000,
  }) {
    return NetworkBoundHttpPlatform.instance.download(
      url: url,
      network: network,
      timeoutMs: timeoutMs,
    );
  }
}
