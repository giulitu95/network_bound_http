<<<<<<< plat-interface
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import 'events/event_factory.dart';
import 'events/events.dart';
import 'network_bound_http_platform_interface.dart';
=======
import 'package:flutter/services.dart';
import 'package:network_bound_http_platform_interface/network_bound_http_platform_interface.dart';
>>>>>>> local

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
<<<<<<< plat-interface
  /// EventChannel used to receive HTTP-related events from the native layer.
  ///
  /// This channel is a broadcast stream shared across multiple concurrent
  /// requests. Incoming events are filtered by request `id` so that each
  /// Dart stream only receives events related to its own request.
  static const EventChannel _eventChannel =
      EventChannel('network_bound_http/events');

  /// MethodChannel used to send commands to the native layer.
  ///
  /// Currently used to trigger the execution of an HTTP request via the
  /// `sendRequest` method.
  static const MethodChannel _methodChannel =
      MethodChannel('network_bound_http/methods');

  /// Factory responsible for converting raw platform event maps into strongly
  /// typed [NetworkBoundHttpEvent] instances.
  ///
  /// This field is marked as [visibleForTesting] to allow injection of
  /// mock implementations during unit tests.
  @visibleForTesting
  EventFactory eventFactory = EventFactory();
=======
  static const EventChannel eventChannel = EventChannel(
    'network_bound_http/events_channel',
  );
  static const MethodChannel requestChannel = MethodChannel(
    'network_bound_http/request_channel',
  );

  Stream<Map<String, dynamic>>? _eventsStream;
>>>>>>> local

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
<<<<<<< plat-interface
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

    // Unique identifier used to correlate platform events with this request.
    final id = const Uuid().v4();
    controller = StreamController<NetworkBoundHttpEvent>(
      onListen: () {
        _eventChannel
            .receiveBroadcastStream()
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
            .where((e) => e['id'] == id)
            .map<NetworkBoundHttpEvent>(
                (rawEvent) => eventFactory.createFromMap(rawEvent))
            .listen(
          (event) {
            controller.add(event);
            if (event is CompleteHttpEvent) {
              controller.close();
            }
          },
          onError: controller.addError,
          onDone: controller.close,
        );

        // Trigger the HTTP request on the native side.
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

      // If the consumer cancels the subscription, the stream is closed.
      onCancel: () {
        controller.close();
      },
    );

    return controller.stream;
=======
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
>>>>>>> local
  }
}
