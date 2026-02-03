import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_bound_http/network_bound_http.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:uuid/data.dart';
import 'package:uuid/uuid.dart';

import 'network_bound_http_platform_mock.dart';

class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async {
    return Directory.systemTemp.path;
  }
}

class NetworkBoundClientMock1 extends NetworkBoundClient {
  bool isExceptionThrown = false;
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
    if (isExceptionThrown) throw Exception("some exception");
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

class NetworkBoundClientMock2 extends NetworkBoundClient {
  String? uriInput;
  String? methodInput;
  Map<String, dynamic>? headersInput;
  Uint8List? bodyInput;
  Duration? connectionTimeoutInput;
  NetworkType? networkTypeInput;

  bool isFetchCalled = false;
  Uint8List? fetchToFileOutput;

  @override
  Future<Uint8List> fetch({
    required String uri,
    required String method,
    Map<String, dynamic>? headers,
    Uint8List? body,
    required Duration connectionTimeout,
    required NetworkType network,
  }) async {
    isFetchCalled = true;
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
  List<String> v4Uuids = [];
  int v4Calls = 0;

  @override
  String v4({
    @Deprecated('use config instead. Removal in 5.0.0')
    Map<String, dynamic>? options,
    V4Options? config,
  }) {
    final res = v4Uuids[v4Calls];
    v4Calls++;
    return res;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
    platformMock.sendRequestCallCounter = 0;
    client.platform = platformMock;
    uuidMock.v4Calls = 0;
    client.uuid = uuidMock;
  });

  group("fetchToFile ok", () {
    test("Correct request/response flow", () async {
      uuidMock.v4Uuids = [requestId];

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
      platformMock.requestInputs = [
        {
          'id': requestId,
          'uri': uri,
          'method': "POST",
          'headers': requestHeaders,
          'timeout': connectionTimeout.inMilliseconds,
          'network': network.name.toUpperCase(),
          'body': body,
          'outputPath': outputFile,
        },
      ];

      final response = await client.postToFile(
        outputFile: File(outputFile),
        uri: uri,
        headers: requestHeaders,
        connectionTimeout: connectionTimeout,
        network: network,
        body: body,
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
    test(
      "Correct request/response flow. event 'done' is not received but event "
      "channel is closed (it should not be possible)",
      () async {
        uuidMock.v4Uuids = [requestId];

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
        ];
        final stream = Stream.fromIterable(events);
        platformMock.callbackStreamOutput = stream;
        platformMock.requestInputs = [
          {
            'id': requestId,
            'uri': uri,
            'method': method,
            'headers': requestHeaders,
            'timeout': connectionTimeout.inMilliseconds,
            'network': network.name.toUpperCase(),
            'outputPath': outputFile,
          },
        ];

        final response = await client.getToFile(
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
        // if it does exit from await for, it means that progressController,
        // has been closed

        expect(
          DeepCollectionEquality().equals(progressSteps, [
            ProgressStep(downloaded: 30, contentLength: 120),
            ProgressStep(downloaded: 60, contentLength: 120),
            ProgressStep(downloaded: 90, contentLength: 120),
            ProgressStep(downloaded: 120, contentLength: 120),
          ]),
          isTrue,
        );
      },
    );
    test("Correct request/response flow 2 simultaneous requests", () async {
      final id1 = requestId;
      final id2 = "2";

      uuidMock.v4Uuids = [id1, id2];

      final events = <Map<String, dynamic>>[
        {
          "id": id1,
          "type": statusEventName,
          "statusCode": statusCode,
          "headers": responseHeaders,
          "outputFile": outputFile,
          "contentLength": contentLength,
        },
        {
          "id": id2,
          "type": statusEventName,
          "statusCode": statusCode,
          "headers": responseHeaders,
          "outputFile": outputFile,
          "contentLength": contentLength,
        },
        for (final d in [30, 60, 90, 120]) ...[
          {
            "id": id1,
            "type": progressEventName,
            "contentLength": contentLength,
            "downloaded": d,
          },
          {
            "id": id2,
            "type": progressEventName,
            "contentLength": contentLength,
            "downloaded": d ~/ 2,
          },
        ],
        {
          "id": id1,
          "type": "done",
          "contentLength": contentLength,
          "downloaded": contentLength,
        },
        for (final d in [75, 90, 105, 120])
          {
            "id": id2,
            "type": progressEventName,
            "contentLength": contentLength,
            "downloaded": d,
          },
        {
          "id": id2,
          "type": "done",
          "contentLength": contentLength,
          "downloaded": contentLength,
        },
      ];
      final stream = Stream.fromIterable(events);
      platformMock.callbackStreamOutput = stream;
      platformMock.requestInputs = [
        {
          'id': id1,
          'uri': uri,
          'method': method,
          'headers': requestHeaders,
          'timeout': connectionTimeout.inMilliseconds,
          'network': network.name.toUpperCase(),
          'outputPath': outputFile,
        },
        {
          'id': id2,
          'uri': uri,
          'method': method,
          'headers': requestHeaders,
          'timeout': connectionTimeout.inMilliseconds,
          'network': network.name.toUpperCase(),
          'outputPath': outputFile,
        },
      ];

      final res1 = await client.getToFile(
        outputFile: File(outputFile),
        uri: uri,
        headers: requestHeaders,
        connectionTimeout: connectionTimeout,
        network: network,
      );
      final progressSteps1 = <ProgressStep>[];
      final future1 = res1.progressStream.forEach(progressSteps1.add);
      final res2 = await client.getToFile(
        outputFile: File(outputFile),
        uri: uri,
        headers: requestHeaders,
        connectionTimeout: connectionTimeout,
        network: network,
      );
      final progressSteps2 = <ProgressStep>[];
      final future2 = res2.progressStream.forEach(progressSteps2.add);

      await future1;
      await future2;
      expect(res1.statusCode, equals(statusCode));
      expect(res1.contentLength, equals(contentLength));
      expect(res2.statusCode, equals(statusCode));
      expect(res2.contentLength, equals(contentLength));

      expect(
        DeepCollectionEquality().equals(
          progressSteps1,
          List.generate(
            120 ~/ 30,
            (i) => ProgressStep(downloaded: (i + 1) * 30, contentLength: 120),
          ),
        ),
        isTrue,
      );
      expect(
        DeepCollectionEquality().equals(
          progressSteps2,
          List.generate(
            120 ~/ 15,
            (i) => ProgressStep(downloaded: (i + 1) * 15, contentLength: 120),
          ),
        ),
        isTrue,
      );
    });
  });
  group("fetchToFile error", () {
    uuidMock.v4Uuids = [requestId];
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
      platformMock.requestInputs = [
        {
          'id': requestId,
          'uri': uri,
          'method': method,
          'headers': requestHeaders,
          'timeout': connectionTimeout.inMilliseconds,
          'network': network.name.toUpperCase(),
          'outputPath': outputFile,
        },
      ];
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

      final response = await client.getToFile(
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

      final response = await client.getToFile(
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

      final response = await client.getToFile(
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

      final response = await client.getToFile(
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

      final response = await client.getToFile(
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
    test("IOException (platform unhandled) while fetching", () async {
      Stream<Map<String, dynamic>> mockStream() async* {
        for (final e in events) {
          yield e;
        }
        throw PlatformException(code: "IOException");
      }

      platformMock.callbackStreamOutput = mockStream();

      final response = await client.getToFile(
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
    test("Unknown Exception while fetching", () async {
      Stream<Map<String, dynamic>> mockStream() async* {
        for (final e in events) {
          yield e;
        }
        throw PlatformException(code: "$requestId::UnknownException");
      }

      platformMock.callbackStreamOutput = mockStream();

      final response = await client.getToFile(
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

      final response = await client.getToFile(
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
        await client.getToFile(
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
    test("Not handled exception before getting status message", () async {
      Stream<Map<String, dynamic>> mockStream() async* {
        throw Exception("message");
      }

      platformMock.callbackStreamOutput = mockStream();

      Object? exception;
      try {
        await client.getToFile(
          outputFile: File(outputFile),
          uri: uri,
          headers: requestHeaders,
          connectionTimeout: connectionTimeout,
          network: network,
        );
      } catch (e) {
        exception = e;
      }
      expect(exception, isA<Exception>());
    });
    test("Not handled exception before getting status message", () async {
      Stream<Map<String, dynamic>> mockStream() async* {
        throw "Unknown stuff";
      }

      platformMock.callbackStreamOutput = mockStream();

      Object? exception;
      try {
        await client.getToFile(
          outputFile: File(outputFile),
          uri: uri,
          headers: requestHeaders,
          connectionTimeout: connectionTimeout,
          network: network,
        );
      } catch (e) {
        exception = e;
      }
      expect(exception, isA<Exception>());
      expect(
        exception.toString(),
        equals("Exception: Platform error: unknown error"),
      );
    });
  });
  group("GET/ POST  request", () {
    late NetworkBoundClientMock1 mock;
    setUp(() {
      mock = NetworkBoundClientMock1();
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
      final res = await mock.getToFile(
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
      NetworkBoundClientMock1 mock = NetworkBoundClientMock1();
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
      final res = await mock.postToFile(
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
  group("fetch", () {
    late NetworkBoundClientMock1 mock;
    late File tmpFile;
    final uuid = "uuidV4";
    final writtenBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6]);
    setUp(() async {
      PathProviderPlatform.instance = FakePathProviderPlatform();
      mock = NetworkBoundClientMock1();
      final uuidMock = UuidMock();
      uuidMock.v4Uuids = ["uuidV4"];
      mock.uuid = uuidMock;
      final tempDir = await getTemporaryDirectory();
      tmpFile = File(p.join(tempDir.path, "$uuid.tmp"));
      await tmpFile.writeAsBytes(writtenBytes);
    });
    tearDown(() async {
      if (await tmpFile.exists()) await tmpFile.delete();
    });
    test("fetch completes normally", () async {
      final events = <ProgressStep>[
        ProgressStep(downloaded: 50, contentLength: contentLength),
      ];
      final stream = Stream.fromIterable(events);
      mock.fetchToFileOutput = NetworkBoundResponse(
        statusCode: 200,
        contentLength: contentLength,
        progressStream: stream,
      );
      mock.outputFileInput = tmpFile;
      mock.uriInput = uri;
      mock.methodInput = method;
      mock.headersInput = requestHeaders;
      mock.bodyInput = body;
      mock.connectionTimeoutInput = connectionTimeout;
      mock.networkTypeInput = network;

      final res = await mock.fetch(
        uri: uri,
        method: method,
        headers: requestHeaders,
        connectionTimeout: connectionTimeout,
        network: network,
        body: body,
      );

      expect(mock.isFetchToFileCalled, isTrue);
      expect(const DeepCollectionEquality().equals(res, writtenBytes), isTrue);
    });

    test("error while fetching completes normally", () async {
      Stream<ProgressStep> mockedStream() async* {
        throw Exception("exception");
      }

      mock.fetchToFileOutput = NetworkBoundResponse(
        statusCode: 200,
        contentLength: contentLength,
        progressStream: mockedStream(),
      );
      mock.outputFileInput = tmpFile;
      mock.uriInput = uri;
      mock.methodInput = method;
      mock.headersInput = requestHeaders;
      mock.bodyInput = body;
      mock.connectionTimeoutInput = connectionTimeout;
      mock.networkTypeInput = network;

      Object? exception;
      try {
        await mock.fetch(
          uri: uri,
          method: method,
          headers: requestHeaders,
          connectionTimeout: connectionTimeout,
          network: network,
          body: body,
        );
      } catch (e) {
        exception = e;
      }

      expect(mock.isFetchToFileCalled, isTrue);
      expect(exception, isA<Exception>());
    });

    test("error while calling fetchToFile", () async {
      mock.isExceptionThrown = true;

      Object? exception;
      try {
        await mock.fetch(
          uri: uri,
          method: method,
          headers: requestHeaders,
          connectionTimeout: connectionTimeout,
          network: network,
          body: body,
        );
      } catch (e) {
        exception = e;
      }

      expect(mock.isFetchToFileCalled, isTrue);
      expect(exception, isA<Exception>());
    });
    test("get", () async {
      final output = Uint8List.fromList([1, 2, 3, 4]);
      final mock2 = NetworkBoundClientMock2();
      mock2.uriInput = uri;
      mock2.methodInput = "GET";
      mock2.headersInput = requestHeaders;
      mock2.connectionTimeoutInput = connectionTimeout;
      mock2.networkTypeInput = network;

      mock2.fetchToFileOutput = output;
      final res = await mock2.get(
        uri: uri,
        headers: requestHeaders,
        connectionTimeout: connectionTimeout,
        network: network,
      );

      expect(mock2.isFetchCalled, isTrue);
      expect(res, equals(output));
    });

    test("post", () async {
      final output = Uint8List.fromList([1, 2, 3, 4]);
      final mock2 = NetworkBoundClientMock2();
      mock2.uriInput = uri;
      mock2.methodInput = "POST";
      mock2.headersInput = requestHeaders;
      mock2.connectionTimeoutInput = connectionTimeout;
      mock2.networkTypeInput = network;
      mock2.bodyInput = body;

      mock2.fetchToFileOutput = output;
      final res = await mock2.post(
        uri: uri,
        body: body,
        headers: requestHeaders,
        connectionTimeout: connectionTimeout,
        network: network,
      );

      expect(mock2.isFetchCalled, isTrue);
      expect(res, equals(output));
    });
  });
}
