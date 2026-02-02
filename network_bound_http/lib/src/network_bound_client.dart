import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:network_bound_http_platform_interface/network_bound_http_platform_interface.dart';
import 'package:uuid/uuid.dart';

enum NetworkType { standard, wifi, cellular }

class NetworkBoundClient {
  @visibleForTesting
  static const defaultConnectionTimeout = Duration(seconds: 4);

  @visibleForTesting
  static const defaultNetwork = NetworkType.standard;

  @visibleForTesting
  NetworkBoundHttpPlatform platform = NetworkBoundHttpPlatform.instance;

  @visibleForTesting
  Uuid uuid = const Uuid();

  Future<NetworkBoundResponse> get({
    required File outputFile,
    required String uri,
    Map<String, dynamic>? headers,
    Duration connectionTimeout = defaultConnectionTimeout,
    NetworkType network = defaultNetwork,
  }) => fetchToFile(
    outputFile: outputFile,
    uri: uri,
    method: "GET",
    headers: headers,
    connectionTimeout: connectionTimeout,
    network: network,
  );

  Future<NetworkBoundResponse> post({
    required File outputFile,
    required String uri,
    Map<String, dynamic>? headers,
    Uint8List? body,
    Duration connectionTimeout = defaultConnectionTimeout,
    NetworkType network = defaultNetwork,
  }) => fetchToFile(
    outputFile: outputFile,
    uri: uri,
    method: "POST",
    body: body,
    connectionTimeout: connectionTimeout,
    network: network,
  );

  Exception _nativeToFlutterException(
    PlatformException nativeException,
    Duration connectionTimeout,
  ) {
    switch (nativeException.code) {
      case "TimeoutCancellationException":
        return TimeoutException(
          "Check the availability of the network selected in your OS",
          connectionTimeout,
        );
      case "SocketException":
      case "UnknownHostException":
        return SocketException(
          nativeException.message != null
              ? nativeException.message!
              : "Your network could not have internet available",
        );
      case "IOException":
        return FileSystemException(
          nativeException.message != null
              ? nativeException.message!
              : "Operation not permitted",
        );
      case "MalformedURLException":
        return FormatException(
          nativeException.message != null
              ? nativeException.message!
              : "Invalid uri",
        );
      default:
        return nativeException;
    }
  }

  @visibleForTesting
  Future<NetworkBoundResponse> fetchToFile({
    required File outputFile,
    required String uri,
    required String method,
    Map<String, dynamic>? headers,
    Uint8List? body,
    required Duration connectionTimeout,
    required NetworkType network,
  }) async {
    final progressController = StreamController<double>.broadcast();
    final completer = Completer<NetworkBoundResponse>();
    final id = uuid.v4();

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
                  NetworkBoundResponse(
                    statusCode: e["statusCode"],
                    contentLength: e["contentLength"],
                    progressStream: progressController.stream,
                  ),
                );
              }
            }
          },
          onError: (error, stack) {
            final exception = error is PlatformException
                ? _nativeToFlutterException(error, connectionTimeout)
                : error;
            if (!completer.isCompleted) {
              completer.completeError(exception, stack);
            } else {
              progressController.addError(exception, stack);
            }
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
        'timeout': connectionTimeout.inMilliseconds,
        'network': network.name.toUpperCase(),
        'outputPath': outputFile.path,
      },
    );

    return completer.future;
  }
}

class NetworkBoundResponse {
  final int statusCode;
  final int contentLength;
  final Stream<double> progressStream;

  NetworkBoundResponse({
    required this.statusCode,
    required this.contentLength,
    required this.progressStream,
  });
}
