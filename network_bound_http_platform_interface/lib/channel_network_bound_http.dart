import 'dart:async';


import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:network_bound_http_platform_interface/types.dart';
import 'package:uuid/uuid.dart';

import 'network_bound_http_platform_interface.dart';

class ChannelNetworkBoundHttp extends NetworkBoundHttpPlatform {

  static const EventChannel _eventChannel =  EventChannel('network_bound_http/events');
  static const MethodChannel _methodChannel = MethodChannel('network_bound_http/methods');


  @visibleForTesting
  final callbackChannel =
      const EventChannel('danfoss_api_wrapper/callback_channel');

  @override
  Stream<NetworkBoundHttpEvent> sendHttpRequest({
    required String uri,
    required String outputPath,
    String method = "GET",
    Map<dynamic, dynamic>? headers,
    Uint8List? body,
    Duration? timeout,
    NetworkType network = NetworkType.standard,
  }) {
    late StreamController<NetworkBoundHttpEvent> controller;
    late StreamSubscription subscription;

    final id = const Uuid().v4();
    controller = StreamController<NetworkBoundHttpEvent>(
      onListen: (){
        _eventChannel
            .receiveBroadcastStream()
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
            .where((e) => e['id'] == id)
            .map<NetworkBoundHttpEvent>((e) {
              switch(e["type"]){
                case "progress":
                  return ProgressHttpEvent(
                    id: e['id'],
                    downloaded: e['downloaded'],
                    total: e['total'], 
                  );
                case "complete":
                  return CompleteHttpEvent(
                      id: e["id"],
                      statusCode: e["statusCode"],
                      headers: e["headers"],
                      outputPath: e["outputFile"]);
                case "error":
                  return ErrorHttpEvent(
                      id: e["id"],
                      message: e["message"]);
                default:
                  //TODO change it
                  return  ErrorHttpEvent(
                      id: e["id"],
                      message: e["message"]);
              }

        })
            .listen(controller.add, onError: controller.addError, onDone: controller.close);

        _methodChannel.invokeMethod("sendRequest", {
          'id': id,
          'uri': uri,
          'method': method,
          if (headers != null) 'headers': headers,
          if (body != null) 'body': body,
          if (timeout != null) 'timeout': timeout.inMilliseconds,
          'network': network.name.toUpperCase(),
          'outputPath': outputPath,
        });
      },
      onCancel: () {
        controller.close();
      },
    );

    return controller.stream;
  }
}
