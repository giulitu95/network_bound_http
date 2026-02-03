import 'package:flutter/services.dart';
import 'package:network_bound_http_platform_interface/network_bound_http_platform_interface.dart';

class NetworkBoundHttpAndroid extends NetworkBoundHttpPlatform {
  static void registerWith() {
    NetworkBoundHttpPlatform.instance = NetworkBoundHttpAndroid();
  }

  static const EventChannel eventChannel = EventChannel(
    'network_bound_http/events_channel_android',
  );
  static const MethodChannel requestChannel = MethodChannel(
    'network_bound_http/request_channel_android',
  );

  Stream<Map<String, dynamic>>? _eventsStream;

  @override
  Stream<Map<String, dynamic>> get callbackStream {
    _eventsStream ??= eventChannel.receiveBroadcastStream().map(
      (event) => Map<String, dynamic>.from(event),
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
