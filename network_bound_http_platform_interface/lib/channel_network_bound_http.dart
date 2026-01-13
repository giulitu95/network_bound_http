import 'dart:async';


import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:network_bound_http_platform_interface/types.dart';
import 'package:streams_channel2/streams_channel2.dart';
import 'package:uuid/uuid.dart';

import 'network_bound_http_platform_interface.dart';

class ChannelNetworkBoundHttp extends NetworkBoundHttpPlatform {

  static final StreamsChannel _streamChannel =  StreamsChannel('network_bound_http/events');
  static const MethodChannel _methodChannel = MethodChannel('network_bound_http/methods');


  @visibleForTesting
  final callbackChannel =
      const EventChannel('danfoss_api_wrapper/callback_channel');

  @override
  Stream<NetworkBoundHttpEvent> sendHttpRequest({
    required String uri,
    String method = "GET",
    Map<String, String>? headers,
    Uint8List? body,
    Duration? timeout,
    NetworkType? network,
  }) {

    late StreamController<NetworkBoundHttpEvent> controller;
    final id = const Uuid().v4();
    controller = StreamController(
      onListen: () {
        _methodChannel.invokeMethod("sendRequest", {
          'id': id,
          'uri': uri,
          'method': method,
          if (headers != null) 'headers': headers,
          if (body != null) 'body': body,
          if (timeout != null) 'timeout': timeout,
          if (network != null) 'network': network.name.toUpperCase(),
        });
      },
      onCancel: () {
        // TODO
      },
    );

    // we return a stream of events tagged only with 'id'
    final stream = _streamChannel.receiveBroadcastStream({'id': id}).map((event){
      return NetworkBoundHttpEvent(
        downloaded: event['downloaded'],
        total: event['total']
      );
    });

    controller.addStream(stream);
    return stream;
  }
}
