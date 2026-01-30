import 'package:flutter/services.dart';
import 'package:network_bound_http_platform_interface/network_bound_http_platform_interface.dart';

/// Platform-specific implementation of [NetworkBoundHttpPlatform] based on
/// Flutter [MethodChannel]s and [EventChannel]s.
///
/// This class acts as the bridge between Dart and the native (Android/iOS)
/// implementation. It sends HTTP requests to the native layer and exposes
/// a [Stream] of [NetworkBoundHttpEvent] objects that describe the lifecycle
/// of the request (e.g. progress updates, completion, errors).
///
/// Each invocation of [sendHttpRequest] generates a unique request identifier
/// (`id`) used to filter events coming from a shared broadcast event channel.
class ChannelNetworkBoundHttp extends NetworkBoundHttpPlatform {
  static const EventChannel eventChannel = EventChannel(
    'network_bound_http/events_channel',
  );
  static const MethodChannel requestChannel = MethodChannel(
    'network_bound_http/request_channel',
  );

  Stream<Map<String, dynamic>>? _eventsStream;

  /// Sends an HTTP request through the native layer and returns a stream of
  /// [NetworkBoundHttpEvent] describing its execution.
  ///
  /// The returned stream emits:
  /// - progress or intermediate events while the request is running
  /// - a [CompleteHttpEvent] when the request completes successfully
  /// - an error event if the request fails
  ///
  /// The stream is automatically closed when a [CompleteHttpEvent] is received
  /// or when the underlying event channel is closed (actually it remains opens
  /// for the entire app life).
  ///
  /// Each call generates a unique request identifier that is sent to the
  /// native layer and used to filter incoming events.
  ///
  /// Parameters:
  /// - [uri]: The target URI of the HTTP request.
  /// - [outputPath]: File system path where the response body should be saved.
  /// - [method]: HTTP method to use (defaults to `"GET"`).
  /// - [headers]: Optional HTTP headers.
  /// - [body]: Optional request body as raw bytes.
  /// - [timeout]: Optional timeout for the request.
  /// - [network]: Network type to be used for the request.
  ///
  /// Returns a [Stream] of [NetworkBoundHttpEvent] associated with this request.
  @override
  Stream<Map<String, dynamic>> get callbackStream {
    _eventsStream ??= eventChannel.receiveBroadcastStream().map(
          (event) => event,
        );
    return _eventsStream!;
  }

  @override
  Future<String?> sendRequest({required Map<String, dynamic> request}) async {
    try {
      return requestChannel.invokeMethod<String?>('sendRequest', request);
    } catch (e) {
      return Future.error(e);
    }
  }
}
