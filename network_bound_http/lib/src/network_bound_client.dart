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

/// Represents a single progress update emitted during a streaming download.
///
/// This class describes the current state of a download in terms of:
/// - [downloaded]: the total number of bytes received so far.
/// - [contentLength]: the total expected size of the response, if known.
///
/// Instances of this class are emitted by the `progressStream` of
/// [NetworkBoundStreamResponse].
class ProgressStep extends Equatable {
  /// Total number of bytes downloaded so far.
  final int downloaded;

  /// Total expected response size in bytes, if known.
  ///
  /// This value may be `null` if the server does not provide a
  /// `Content-Length` header.
  final int? contentLength;

  @visibleForTesting
  const ProgressStep({required this.downloaded, required this.contentLength});

  @override
  List<Object?> get props => [downloaded, contentLength];
}

/// Core client for performing network requests within the library.
///
/// Provides the primary interface for executing HTTP requests with
/// selectable network types ([NetworkType.wifi], [NetworkType.cellular], or [NetworkType.standard])
/// and returning either fully buffered responses ([NetworkBoundCompleteResponse])
/// or streaming downloads ([NetworkBoundStreamResponse]).
///
/// All request-specific parameters (URI, headers, timeout, etc.) are passed
/// directly to the request methods.
class NetworkBoundClient {
  @visibleForTesting
  static const defaultConnectionTimeout = Duration(seconds: 4);

  @visibleForTesting
  static const defaultNetwork = NetworkType.standard;

  @visibleForTesting
  NetworkBoundHttpPlatform platform = NetworkBoundHttpPlatform.instance;

  @visibleForTesting
  Uuid uuid = const Uuid();

  /// Performs an HTTP **GET** request and streams the response directly into a file,
  /// allowing the caller to specify the network interface and monitor download progress.
  ///
  /// The function **returns immediately as soon as the connection is established**,
  /// without waiting for the download to complete. The download progress can be tracked
  /// by listening to the `progressStream` contained in the returned
  /// [NetworkBoundStreamResponse].
  ///
  /// ## Behavior
  /// - Sends an HTTP **GET** request to the provided [uri].
  /// - The request is executed using the selected [network] interface.
  /// - The response body is written directly into [outputFile].
  /// - Progress updates are emitted through `progressStream`.
  /// - When the stream completes, the download is finished.
  /// - If an error occurs, the stream emits an error event.
  ///
  /// ## Parameters
  /// - [outputFile]: Destination file where the downloaded data will be written.
  /// - [uri]: The target URI for the GET request.
  /// - [headers]: Optional HTTP headers.
  /// - [connectionTimeout]: Maximum duration to wait before the connection attempt
  ///   times out and throws an exception.
  /// - [network]: Network interface to use for the request:
  ///   - [NetworkType.wifi]
  ///   - [NetworkType.cellular]
  ///   - [NetworkType.standard]
  ///
  /// ## Returns
  /// Returns a [NetworkBoundStreamResponse] which contains:
  /// - `progressStream`: A stream of progress events that can be listened to in order
  ///   to track the download state. When the stream completes, the download is finished.
  /// - other info related to the http connection
  ///
  /// ## Example
  /// ```dart
  /// final response = await getToFile(
  ///   outputFile: file,
  ///   uri: 'https://example.com/large-file.zip',
  ///   network: NetworkType.cellular,
  /// );
  ///
  /// response.progressStream.listen(
  ///   (event) {
  ///     print('Downloaded: ${event.downloaded} / ${event.contentLength}');
  ///   },
  ///   onDone: () {
  ///     print('Download completed');
  ///   },
  ///   onError: (e) {
  ///     print('Download failed: $e');
  ///   },
  /// );
  /// ```
  ///
  /// ## Notes
  /// - This method does **not block** until the download completes.
  /// - Make sure to listen to the stream to properly handle completion and errors.
  /// - The caller is responsible for managing the lifecycle of the output file.
  ///
  /// ## Throws
  /// - [TimeoutException] if the connection is not established within [connectionTimeout].
  /// - [Exception] for network, I/O, or protocol errors.
  Future<NetworkBoundStreamResponse> getToFile({
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

  /// Performs an HTTP **GET** request and returns the fully buffered response.
  ///
  /// This method behaves similarly to [getToFile], but instead of streaming the
  /// response into a file, it **buffers the entire response body in memory** and
  /// returns it directly inside a [NetworkBoundCompleteResponse].
  ///
  /// The function **completes only when the full response has been received**.
  /// For large payloads, consider using [getToFile] to avoid excessive memory usage.
  ///
  /// ## Behavior
  /// - Sends an HTTP **GET** request to the provided [uri].
  /// - The request is executed using the selected [network] interface.
  /// - The response body is fully downloaded and buffered in memory.
  /// - The method completes only after the full payload has been received.
  /// - If an error occurs, the returned future completes with an exception.
  ///
  /// ## Parameters
  /// - [uri]: The target URI for the GET request.
  /// - [headers]: Optional HTTP headers.
  /// - [connectionTimeout]: Maximum duration to wait before the connection attempt
  ///   times out and throws an exception.
  /// - [network]: Network interface to use for the request:
  ///   - [NetworkType.wifi]
  ///   - [NetworkType.cellular]
  ///   - [NetworkType.standard]
  ///
  /// ## Returns
  /// Returns a [NetworkBoundCompleteResponse] containing:
  /// - The full response body as a [Uint8List].
  /// - HTTP status information.
  /// - Response headers and metadata.
  ///
  /// ## Example
  /// ```dart
  /// final response = await get(
  ///   uri: 'https://api.example.com/data',
  ///   network: NetworkType.wifi,
  /// );
  ///
  /// print('Status: ${response.statusCode}');
  /// print('Body bytes: ${response.body.length}');
  /// ```
  ///
  /// ## Notes
  /// - This method **buffers the entire response in memory**.
  /// - For large responses, prefer [getToFile] to reduce memory pressure.
  /// - If you need progress reporting, use [getToFile].
  ///
  /// ## Throws
  /// - [TimeoutException] if the connection is not established within
  ///   [connectionTimeout].
  /// - [Exception] for network, protocol, or I/O errors.
  Future<NetworkBoundCompleteResponse> get({
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

  /// Performs an HTTP **POST** request and streams the response directly into a file.
  ///
  /// This method behaves exactly like [getToFile], but uses the HTTP **POST** method
  /// instead of **GET**.
  ///
  /// See [getToFile] for detailed behavior, progress handling, and error semantics.
  ///
  /// ## Additional Parameters
  /// - [body]: The request payload to send with the POST request.
  /// - [encoding]: Encoding used for the request body.
  Future<NetworkBoundStreamResponse> postToFile({
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

  /// Performs an HTTP **POST** request and returns the fully buffered response.
  ///
  /// This method behaves exactly like [get], but uses the HTTP **POST** method
  /// instead of **GET**, allowing a request payload to be sent.
  ///
  /// See [get] for detailed behavior, response handling, memory usage, and
  /// error semantics.
  ///
  /// ## Additional Parameters
  /// - [body]: The request payload to send with the POST request.
  /// - [encoding]: Encoding used to serialize the request body.
  ///
  /// ## Example
  /// ```dart
  /// final response = await post(
  ///   uri: 'https://api.example.com/login',
  ///   body: {'username': 'user', 'password': 'pass'},
  /// );
  ///
  /// print('Status: ${response.statusCode}');
  /// print('Body bytes: ${response.body.length}');
  /// ```
  ///
  /// ## See also
  /// - [get] for buffered GET requests.
  /// - [postToFile] for streaming POST downloads into a file.
  Future<NetworkBoundCompleteResponse> post({
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
  Future<NetworkBoundCompleteResponse> fetch({
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
        return NetworkBoundCompleteResponse(
          statusCode: res.statusCode,
          contentLength: res.contentLength,
          headers: res.headers,
          body: output,
        );
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
  Future<NetworkBoundStreamResponse> fetchToFile({
    required File outputFile,
    required String uri,
    required String method,
    Map<String, dynamic>? headers,
    Uint8List? body,
    required Duration connectionTimeout,
    required NetworkType network,
  }) async {
    final progressController = StreamController<ProgressStep>.broadcast();
    final completer = Completer<NetworkBoundStreamResponse>();
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
                  NetworkBoundStreamResponse(
                    statusCode: e["statusCode"],
                    contentLength: e["contentLength"],
                    headers: e["headers"],
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

/// Represents a streaming HTTP response.
///
/// Contains a [progressStream] that emits [ProgressStep] events
/// to track download progress in real time.
/// Used as the return type of streaming requests (`getToFile`, `postToFile`).
class NetworkBoundStreamResponse extends NetworkBoundResponse {
  /// Stream of progress updates during the download.
  final Stream<ProgressStep> progressStream;

  NetworkBoundStreamResponse({
    required super.statusCode,
    super.contentLength,
    super.headers,
    required this.progressStream,
  });
}

/// Represents a fully buffered HTTP response.
///
/// Contains the complete response [body] as a [Uint8List].
/// Used as the return type of buffered requests (`get`, `post`).
class NetworkBoundCompleteResponse extends NetworkBoundResponse {
  /// Response body as a [Uint8List].
  final Uint8List body;

  NetworkBoundCompleteResponse({
    required super.statusCode,
    super.contentLength,
    super.headers,
    required this.body,
  });
}

/// Represents a generic HTTP response.
///
/// Contains common metadata returned by any network request:
/// - [statusCode]: the HTTP status code of the response.
/// - [contentLength]: the total size of the response in bytes, if known.
/// - [headers]: optional HTTP response headers.
abstract class NetworkBoundResponse {
  /// HTTP status code of the response.
  final int statusCode;

  /// Total expected response size in bytes, if known.
  ///
  /// May be `null` if the server does not provide a `Content-Length` header.
  final int? contentLength;

  /// HTTP response headers, if available.
  final Map<dynamic, dynamic>? headers;

  NetworkBoundResponse({
    required this.statusCode,
    this.contentLength,
    this.headers,
  });
}
