import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:network_bound_http_platform_interface/network_bound_http_platform_interface.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
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

  Future<NetworkBoundResponse> getToFile({
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

  Future<Uint8List> get({
    required String uri,
    Map<String, dynamic>? headers,
    Duration connectionTimeout = defaultConnectionTimeout,
    NetworkType network = defaultNetwork,
  }) => fetch(
    uri: uri,
    method: "GET",
    headers: headers,
    connectionTimeout: connectionTimeout,
    network: network,
  );

  Future<NetworkBoundResponse> postToFile({
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

  Future<Uint8List> post({
    required String uri,
    Map<String, dynamic>? headers,
    Uint8List? body,
    Duration connectionTimeout = defaultConnectionTimeout,
    NetworkType network = defaultNetwork,
  }) => fetch(
    uri: uri,
    method: "POST",
    headers: headers,
    body: body,
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
  Exception? handlePlatformError(
    final dynamic error,
    final dynamic stack,
    final String requestId,
    final Duration connectionTimeout,
  ) {
    if (error is PlatformException) {
      // If the platform exception is handled by the native code,
      // the error code is composed by <requestId>::<ExceptionType>
      final splitError = error.code.split("::");
      if (splitError.length > 1) {
        if (splitError[0] == requestId) {
          // We try to convert a native exception to a flutter exception
          return _nativeToFlutterException(
            splitError[1],
            error.message,
            connectionTimeout,
          );
        } else {
          // The exception does not refer to this request. It is ignored
          return null;
        }
      } else {
        // Thi is the case in which a platform unhandled error is thrown, hence
        // the error does not contain the request id.
        // If this does happen, it could be a problem because other listeners
        // of other requests that are open at the same time, all receive the same
        // error, regardless of the request id
        return _nativeToFlutterException(
          error.code,
          error.message,
          connectionTimeout,
        );
      }
    } else {
      // This is the case in which an Unhandled error is thrown.
      // If this does happen, it could be a problem because other listeners
      // of other requests that are open at the same time, all receive the same
      // error, regardless of the request id
      return error is Exception
          ? error
          : Exception("Platform error: unknown error");
    }
  }

  @visibleForTesting
  Future<Uint8List> fetch({
    required String uri,
    required String method,
    Map<String, dynamic>? headers,
    Uint8List? body,
    required Duration connectionTimeout,
    required NetworkType network,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final destFile = File(join(tempDir.path, "${uuid.v4()}.tmp"));
    try {
      final res = await fetchToFile(
        outputFile: destFile,
        uri: uri,
        method: method,
        body: body,
        headers: headers,
        connectionTimeout: connectionTimeout,
        network: network,
      );
      try {
        await for (final _ in res.progressStream) {}
        final output = await destFile.readAsBytes();
        return output;
      } catch (e, _) {
        if (await destFile.exists()) await destFile.delete();
        rethrow;
      }
    } catch (e) {
      if (await destFile.exists()) await destFile.delete();
      rethrow;
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
                  // Sometimes contentLength is not specified (in this case, it
                  // is equal to -1
                  contentLength: contentLength == -1 ? null : contentLength,
                ),
              );
            } else if (e["type"] == "done") {
              // In this case we close the streamController the user is
              // listening to and we close the platform-events subscription
              progressController.close();
              subscription.cancel();
            } else if (e["type"] == "status") {
              if (!completer.isCompleted) {
                // As soon as a status event arrives, we return from the
                // fetchToFile function
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
          onError: (error, stack) async {
            final exception = handlePlatformError(
              error,
              stack,
              id,
              connectionTimeout,
            );
            if (exception != null) {
              if (!completer.isCompleted) {
                completer.completeError(exception, stack);
              } else if (!progressController.isClosed) {
                progressController.addError(exception, stack);
                progressController.close();
              }
              subscription.cancel();
            } else {
              // do nothing, the error does not refer to this request
            }
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
