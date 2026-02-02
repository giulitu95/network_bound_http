import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:network_bound_http_platform_interface/network_bound_http_platform_interface.dart';
import 'package:uuid/uuid.dart';

enum NetworkType { standard, wifi, cellular }

class ProgressStep extends Equatable {
  final int downloaded;
  final int? contentLength;

  const ProgressStep({required this.downloaded, required this.contentLength});

  @override
  List<Object?> get props => [downloaded, contentLength];
}

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
    headers: headers,
    connectionTimeout: connectionTimeout,
    network: network,
  );

  Exception _nativeToFlutterException(
    String code,
    String? message,
    Duration connectionTimeout,
  ) {
    switch (code) {
      case "TimeoutCancellationException":
        return TimeoutException(
          "Check the availability of the network selected in your OS",
          connectionTimeout,
        );
      case "SocketException":
      case "UnknownHostException":
        return SocketException(
          message ?? "Your network could not have internet available",
        );
      case "IOException":
        return FileSystemException(message ?? "Operation not permitted");
      case "MalformedURLException":
        return FormatException(message ?? "Invalid uri");
      default:
        return PlatformException(code: code, message: message);
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
    final progressController = StreamController<ProgressStep>.broadcast();
    final completer = Completer<NetworkBoundResponse>();
    final id = uuid.v4();

    late StreamSubscription subscription;
    subscription = platform.callbackStream
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => e['id'] == id)
        .listen(
          (e) {
            if (e["type"] == "progress") {
              final int downloadedBytes = e["downloaded"];
              final int contentLength = e["contentLength"];
              progressController.add(
                ProgressStep(
                  downloaded: downloadedBytes,
                  contentLength: contentLength == -1 ? null : contentLength,
                ),
              );
            } else if (e["type"] == "done") {
              progressController.close();
              subscription.cancel();
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
            late Exception exception;
            if (error is PlatformException) {
              final splitError = error.code.split("::");
              if (splitError[0] == id) {
                exception = _nativeToFlutterException(
                  splitError[1],
                  error.message,
                  connectionTimeout,
                );
              }
            } else {
              // If this does happen it could be problem because other listeners
              // of other requests that are open at the same time, all receive
              // and must handle the error
              exception = error;
            }
            if (!completer.isCompleted) {
              completer.completeError(exception, stack);
            } else if (!progressController.isClosed) {
              progressController.addError(exception, stack);
              progressController.close();
            }
            subscription.cancel();
          },
          onDone: () {
            // It should never reach here since the callback stream is an infinite
            // stream
            progressController.close();
            subscription.cancel();
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

  // contentLength could be not defined
  final int? contentLength;
  final Stream<ProgressStep> progressStream;

  NetworkBoundResponse({
    required this.statusCode,
    required this.contentLength,
    required this.progressStream,
  });
}
