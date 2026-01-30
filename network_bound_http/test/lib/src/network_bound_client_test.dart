import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_bound_http/network_bound_http.dart';
import 'package:uuid/data.dart';
import 'package:uuid/uuid.dart';

import 'network_bound_http_platform_mock.dart';

class UuidMock extends Fake implements Uuid {
  String? v4Uuid;

  @override
  String v4({
    @Deprecated('use config instead. Removal in 5.0.0')
    Map<String, dynamic>? options,
    V4Options? config,
  }) {
    assert(v4Uuid != null);
    return v4Uuid!;
  }
}

void main() {
  const progressEventName = "progress";
  const statusEventName = "status";
  final platformMock = NetworkBoundHttpPlatformMock();
  final uuidMock = UuidMock();
  final client = NetworkBoundClient();
  final uri = "uri";
  final method = "GET";
  final requestId = "1";
  final responseHeaders = {};
  final outputFile = "outputFile";
  final contentLength = 120;
  final requestHeaders = {
    "headerKey1": "headerValue1",
    "headerKey2": "headerValue2",
  };
  final connectionTimeout = Duration(seconds: 2);
  final network = NetworkType.standard;
  final statusCode = 200;

  setUp(() {
    client.platform = platformMock;
    client.uuid = uuidMock;
  });

  group("fetchToFile", () {
    test("Correct request/response flow", () async {
      uuidMock.v4Uuid = requestId;

      final events = <Map<String, dynamic>>[
        {
          "id": requestId,
          "type": statusEventName,
          "statusCode": statusCode,
          "headers": responseHeaders,
          "outputFile": outputFile,
          "contentLength": contentLength,
        },
        for (final d in [30, 60, 90])
          {
            "id": requestId,
            "type": progressEventName,
            "contentLength": contentLength,
            "downloaded": d,
          },
        {
          "id": requestId,
          "type": progressEventName,
          "contentLength": contentLength,
          "downloaded": contentLength,
        },
      ];
      final stream = Stream.fromIterable(events);
      platformMock.callbackStreamOutput = stream;
      platformMock.sendRequestOutput = null;
      platformMock.requestInput = {
        'id': requestId,
        'uri': uri,
        'method': method,
        'headers': requestHeaders,
        'timeout': connectionTimeout.inMilliseconds,
        'network': network.name.toUpperCase(),
        'outputPath': outputFile,
      };

      final response = await client.get(
        outputFile: File(outputFile),
        uri: uri,
        headers: requestHeaders,
        connectionTimeout: connectionTimeout,
        network: network,
      );

      expect(response.statusCode, equals(statusCode));
      expect(response.contentLength, equals(contentLength));

      final progressSteps = <double>[];
      await for (final newProgress in response.progressStream) {
        progressSteps.add(newProgress);
      }

      expect(
        DeepCollectionEquality().equals(progressSteps, [0.25, 0.5, 0.75, 1]),
        isTrue,
      );
    });
  });
}
