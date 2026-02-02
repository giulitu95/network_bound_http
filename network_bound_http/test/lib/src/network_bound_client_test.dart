import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_bound_http/network_bound_http.dart';
import 'package:uuid/data.dart';
import 'package:uuid/uuid.dart';

import 'network_bound_http_platform_mock.dart';

class NetworkBoundClientMock extends NetworkBoundClient {
  File? outputFileInput;
  String? uriInput;
  String? methodInput;
  Map<String, dynamic>? headersInput;
  Uint8List? bodyInput;
  Duration? connectionTimeoutInput;
  NetworkType? networkTypeInput;

  bool isFetchToFileCalled = false;
  NetworkBoundResponse? fetchToFileOutput;

  @override
  Future<NetworkBoundResponse> fetchToFile({
    required File outputFile,
    required String uri,
    required String method,
    Map<String, dynamic>? headers,
    Uint8List? body,
    required Duration connectionTimeout,
    required NetworkType network,
  }) async {
    isFetchToFileCalled = true;
    expect(outputFileInput!.path, equals(outputFile.path));
    expect(uriInput, equals(uri));
    expect(methodInput, equals(method));
    expect(
      const DeepCollectionEquality.unordered().equals(headersInput, headers),
      isTrue,
    );
    expect(bodyInput, equals(body));
    expect(connectionTimeoutInput, equals(connectionTimeout));
    expect(networkTypeInput, equals(network));

    assert(fetchToFileOutput != null);
    return fetchToFileOutput!;
  }
}

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
  final body = Uint8List.fromList([1, 2, 3]);

  setUp(() {
    client.platform = platformMock;
    client.uuid = uuidMock;
  });

  group("fetchToFile ok", () {
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
        for (final d in [30, 60, 90, 120])
          {
            "id": requestId,
            "type": progressEventName,
            "contentLength": contentLength,
            "downloaded": d,
          },
        {
          "id": requestId,
          "type": "done",
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

      final progressSteps = <ProgressStep>[];
      await for (final newProgress in response.progressStream) {
        progressSteps.add(newProgress);
      }

      expect(
        DeepCollectionEquality().equals(progressSteps, [
          ProgressStep(downloaded: 30, contentLength: 120),
          ProgressStep(downloaded: 60, contentLength: 120),
          ProgressStep(downloaded: 90, contentLength: 120),
          ProgressStep(downloaded: 120, contentLength: 120),
        ]),
        isTrue,
      );
    });
  });
  group("fetchToFile error", () {
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
      {
        "id": requestId,
        "type": progressEventName,
        "contentLength": contentLength,
        "downloaded": 30,
      },
    ];

    setUp(() {
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
    });
    test("TimeoutCancellationException while fetching", () async {
      Stream<Map<String, dynamic>> mockStream() async* {
        for (final e in events) {
          yield e;
        }
        throw PlatformException(
          code: "$requestId::TimeoutCancellationException",
        );
      }

      platformMock.callbackStreamOutput = mockStream();

      final response = await client.get(
        outputFile: File(outputFile),
        uri: uri,
        headers: requestHeaders,
        connectionTimeout: connectionTimeout,
        network: network,
      );
      expect(response.statusCode, equals(statusCode));
      expect(response.contentLength, equals(contentLength));

      final progressSteps = <ProgressStep>[];
      Object? exception;
      try {
        await for (final newProgress in response.progressStream) {
          progressSteps.add(newProgress);
        }
      } catch (e) {
        exception = e;
      }

      expect(
        DeepCollectionEquality().equals(progressSteps, [
          ProgressStep(downloaded: 30, contentLength: 120),
        ]),
        isTrue,
      );
      expect(exception, isA<TimeoutException>());
    });

    test("SocketException while fetching", () async {
      Stream<Map<String, dynamic>> mockStream() async* {
        for (final e in events) {
          yield e;
        }
        throw PlatformException(code: "$requestId::SocketException");
      }

      platformMock.callbackStreamOutput = mockStream();

      final response = await client.get(
        outputFile: File(outputFile),
        uri: uri,
        headers: requestHeaders,
        connectionTimeout: connectionTimeout,
        network: network,
      );
      expect(response.statusCode, equals(statusCode));
      expect(response.contentLength, equals(contentLength));

      final progressSteps = <ProgressStep>[];
      Object? exception;
      try {
        await for (final newProgress in response.progressStream) {
          progressSteps.add(newProgress);
        }
      } catch (e) {
        exception = e;
      }

      expect(
        DeepCollectionEquality().equals(progressSteps, [
          ProgressStep(downloaded: 30, contentLength: 120),
        ]),
        isTrue,
      );
      expect(exception, isA<SocketException>());
    });
    test("UnknownHostException while fetching", () async {
      Stream<Map<String, dynamic>> mockStream() async* {
        for (final e in events) {
          yield e;
        }
        throw PlatformException(code: "$requestId::UnknownHostException");
      }

      platformMock.callbackStreamOutput = mockStream();

      final response = await client.get(
        outputFile: File(outputFile),
        uri: uri,
        headers: requestHeaders,
        connectionTimeout: connectionTimeout,
        network: network,
      );
      expect(response.statusCode, equals(statusCode));
      expect(response.contentLength, equals(contentLength));

      final progressSteps = <ProgressStep>[];
      Object? exception;
      try {
        await for (final newProgress in response.progressStream) {
          progressSteps.add(newProgress);
        }
      } catch (e) {
        exception = e;
      }

      expect(
        DeepCollectionEquality().equals(progressSteps, [
          ProgressStep(downloaded: 30, contentLength: 120),
        ]),
        isTrue,
      );
      expect(exception, isA<SocketException>());
    });

    test("IOException while fetching", () async {
      Stream<Map<String, dynamic>> mockStream() async* {
        for (final e in events) {
          yield e;
        }
        throw PlatformException(code: "$requestId::IOException");
      }

      platformMock.callbackStreamOutput = mockStream();

      final response = await client.get(
        outputFile: File(outputFile),
        uri: uri,
        headers: requestHeaders,
        connectionTimeout: connectionTimeout,
        network: network,
      );
      expect(response.statusCode, equals(statusCode));
      expect(response.contentLength, equals(contentLength));

      final progressSteps = <ProgressStep>[];
      Object? exception;
      try {
        await for (final newProgress in response.progressStream) {
          progressSteps.add(newProgress);
        }
      } catch (e) {
        exception = e;
      }

      expect(
        DeepCollectionEquality().equals(progressSteps, [
          ProgressStep(downloaded: 30, contentLength: 120),
        ]),
        isTrue,
      );
      expect(exception, isA<FileSystemException>());
    });

    test("MalformedURLException while fetching", () async {
      Stream<Map<String, dynamic>> mockStream() async* {
        for (final e in events) {
          yield e;
        }
        throw PlatformException(code: "$requestId::MalformedURLException");
      }

      platformMock.callbackStreamOutput = mockStream();

      final response = await client.get(
        outputFile: File(outputFile),
        uri: uri,
        headers: requestHeaders,
        connectionTimeout: connectionTimeout,
        network: network,
      );
      expect(response.statusCode, equals(statusCode));
      expect(response.contentLength, equals(contentLength));

      final progressSteps = <ProgressStep>[];
      Object? exception;
      try {
        await for (final newProgress in response.progressStream) {
          progressSteps.add(newProgress);
        }
      } catch (e) {
        exception = e;
      }

      expect(
        DeepCollectionEquality().equals(progressSteps, [
          ProgressStep(downloaded: 30, contentLength: 120),
        ]),
        isTrue,
      );
      expect(exception, isA<FormatException>());
    });
    test("Unknown Exception while fetching", () async {
      Stream<Map<String, dynamic>> mockStream() async* {
        for (final e in events) {
          yield e;
        }
        throw PlatformException(code: "$requestId::UnknownException");
      }

      platformMock.callbackStreamOutput = mockStream();

      final response = await client.get(
        outputFile: File(outputFile),
        uri: uri,
        headers: requestHeaders,
        connectionTimeout: connectionTimeout,
        network: network,
      );
      expect(response.statusCode, equals(statusCode));
      expect(response.contentLength, equals(contentLength));

      final progressSteps = <ProgressStep>[];
      Object? exception;
      try {
        await for (final newProgress in response.progressStream) {
          progressSteps.add(newProgress);
        }
      } catch (e) {
        exception = e;
      }

      expect(
        DeepCollectionEquality().equals(progressSteps, [
          ProgressStep(downloaded: 30, contentLength: 120),
        ]),
        isTrue,
      );
      expect(exception, isA<PlatformException>());
    });

    test("Exception is not PlatformException", () async {
      Stream<Map<String, dynamic>> mockStream() async* {
        for (final e in events) {
          yield e;
        }
        throw CertificateException();
      }

      platformMock.callbackStreamOutput = mockStream();

      final response = await client.get(
        outputFile: File(outputFile),
        uri: uri,
        headers: requestHeaders,
        connectionTimeout: connectionTimeout,
        network: network,
      );
      expect(response.statusCode, equals(statusCode));
      expect(response.contentLength, equals(contentLength));

      final progressSteps = <ProgressStep>[];
      Object? exception;
      try {
        await for (final newProgress in response.progressStream) {
          progressSteps.add(newProgress);
        }
      } catch (e) {
        exception = e;
      }

      expect(
        DeepCollectionEquality().equals(progressSteps, [
          ProgressStep(downloaded: 30, contentLength: 120),
        ]),
        isTrue,
      );
      expect(exception, isA<CertificateException>());
    });

    test("FormatException before getting status message", () async {
      Stream<Map<String, dynamic>> mockStream() async* {
        throw PlatformException(code: "$requestId::MalformedURLException");
      }

      platformMock.callbackStreamOutput = mockStream();

      Object? exception;
      try {
        await client.get(
          outputFile: File(outputFile),
          uri: uri,
          headers: requestHeaders,
          connectionTimeout: connectionTimeout,
          network: network,
        );
      } catch (e) {
        exception = e;
      }
      expect(exception, isA<FormatException>());
    });
  });
  group("GET/ POST  request", () {
    late NetworkBoundClientMock mock;
    setUp(() {
      mock = NetworkBoundClientMock();
    });
    test("GET request calls fetchToFile", () async {
      mock.outputFileInput = File(outputFile);
      mock.uriInput = uri;
      mock.methodInput = "GET";
      mock.headersInput = requestHeaders;
      mock.connectionTimeoutInput = connectionTimeout;
      mock.networkTypeInput = network;

      final mockedRes = NetworkBoundResponse(
        statusCode: 200,
        contentLength: contentLength,
        progressStream: Stream.empty(),
      );

      mock.fetchToFileOutput = mockedRes;
      final res = await mock.get(
        outputFile: File(outputFile),
        uri: uri,
        headers: requestHeaders,
        connectionTimeout: connectionTimeout,
        network: network,
      );

      expect(mock.isFetchToFileCalled, isTrue);
      expect(res, equals(mockedRes));
    });

    test("POST request calls fetchToFile", () async {
      NetworkBoundClientMock mock = NetworkBoundClientMock();
      mock.outputFileInput = File(outputFile);
      mock.uriInput = uri;
      mock.methodInput = "POST";
      mock.headersInput = requestHeaders;
      mock.bodyInput = body;
      mock.connectionTimeoutInput = connectionTimeout;
      mock.networkTypeInput = network;

      final mockedRes = NetworkBoundResponse(
        statusCode: 200,
        contentLength: contentLength,
        progressStream: Stream.empty(),
      );
      mock.fetchToFileOutput = mockedRes;
      final res = await mock.post(
        outputFile: File(outputFile),
        uri: uri,
        headers: requestHeaders,
        connectionTimeout: connectionTimeout,
        network: network,
        body: body,
      );

      expect(mock.isFetchToFileCalled, isTrue);
      expect(res, equals(mockedRes));
    });
  });
}
