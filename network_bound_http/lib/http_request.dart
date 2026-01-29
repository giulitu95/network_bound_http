import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:network_bound_http_platform_interface/network_bound_http_platform_interface.dart';
import 'package:uuid/uuid.dart';

enum NetworkType { standard, wifi, cellular }

class Response {
  final int statusCode;
  final int contentLength;
  final Stream<double> progressStream;

  Response({
    required this.statusCode,
    required this.contentLength,
    required this.progressStream,
  });
}

class NbHttpRequest {
  final String uri;
  final String outputPath;
  final String method;
  final Map<String, dynamic>? headers;
  final Uint8List? body;
  final Duration? timeout;
  final NetworkType network;

  NetworkBoundHttpPlatform get platform => NetworkBoundHttpPlatform.instance;

  NbHttpRequest({
    required this.uri,
    required this.outputPath,
    this.method = "GET",
    this.headers,
    this.body,
    this.timeout,
    this.network = NetworkType.standard,
  });

  Future<Response> sendRequest() async {
    final progressController = StreamController<double>.broadcast();
    final completer = Completer<Response>();
    final id = const Uuid().v4();

    platform.callbackStream
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => e['id'] == id)
        .listen(
          (e) {
            if (e["type"] == "progress") {
              final int downloadedBytes = e["downloaded"];
              final int contentLength = e["contentLength"];
              progressController.add(downloadedBytes / contentLength);
              if (downloadedBytes >= contentLength) {
                progressController.close();
              }
            } else if (e["type"] == "status") {
              if (!completer.isCompleted) {
                completer.complete(
                  Response(
                    statusCode: e["statusCode"],
                    contentLength: e["contentLength"],
                    progressStream: progressController.stream,
                  ),
                );
              }
            }
          },
          onError: (error, stack) {
            if (!completer.isCompleted) {
              completer.completeError(error, stack);
            }
            progressController.addError(error, stack);
          },
          onDone: () {
            // It should never reach here since the callback stream is an infinite
            // stream
            progressController.close();
          },
        );

    await platform.sendRequest(
      request: {
        'id': id,
        'uri': uri,
        'method': method,
        if (headers != null) 'headers': headers,
        if (body != null) 'body': body,
        if (timeout != null) 'timeout': timeout!.inMilliseconds,
        'network': network.name.toUpperCase(),
        'outputPath': outputPath,
      },
    );

    return completer.future;
  }
}
