import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'danfoss_api_wrapper_platform_interface.dart';

/// An implementation of [DanfossApiWrapperPlatform] that uses Flutter SDK
/// channels (MethodChannel and EventChannel).
class ChannelDanfossApiWrapper extends DanfossApiWrapperPlatform {
  @visibleForTesting
  final syncChannel = const MethodChannel('danfoss_api_wrapper/sync_channel');

  @visibleForTesting
  final callbackChannel =
      const EventChannel('danfoss_api_wrapper/callback_channel');

  @override
  Future<String?> callService(String jsonRequest) async {
    try {
      return syncChannel.invokeMethod<String>(
        'callService',
        <String, String>{'request': jsonRequest},
      );
    } catch (e) {
      return Future.error(e);
    }
  }

  Stream<String>? _callbackStream;

  @override
  Stream<String> get callbackStream {
    _callbackStream ??= callbackChannel
        .receiveBroadcastStream()
        .map((event) => event.toString());
    return _callbackStream!;
  }

  @override
  Future<bool> initialize() => Future.value(true);
}
