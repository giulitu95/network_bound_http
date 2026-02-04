# Network Bound HTTP
[![codecov](https://codecov.io/github/giulitu95/network_bound_http/graph/badge.svg?token=10A84VB9V1)](https://codecov.io/github/giulitu95/network_bound_http)

`network_bound_http` is a federated Flutter plugin that allows performing HTTP **GET** and **POST** requests using a specific network interface, such as Wi-Fi, cellular, or the default network.

This is particularly useful in advanced scenarios like:

- Custom routing between Wi-Fi and cellular networks.
- Accessing a local Wi-Fi network without internet while simultaneously using cellular data for internet access on Android devices.

⚠️ **Currently, the plugin supports Android only**, as iOS and Windows automatically switch to a network with internet access when Wi-Fi has no connectivity.

## Key Features

- **Network selection for requests**: Wi-Fi, cellular, or default.
- **Direct download to file**: Writes the response body directly to a file and provides a progress stream.
- **In-memory response**: Retrieves the full response content in memory without saving to a file.
- **Progress tracking**: Stream the download progress in bytes and access content length if available.

## Installation

Add the dependency to your pubspec.yaml:

```yaml
dependencies:
  network_bound_http: ^1.0.0
```

Import the package in your Dart file:

```dart
import 'package:network_bound_http/network_bound_http.dart';
```

## Usage
### 1. Downloading directly to a filegit add 

```dart
import 'dart:io';
import 'package:network_bound_http/network_bound_http.dart';

final client = NetworkBoundClient();
final outputFile = File('/path/to/output.file');

try {
  final res = await client.getToFile(
    outputFile: outputFile,
    uri: 'https://example.com/file',
    network: NetworkType.wifi, // NetworkType.cellular, NetworkType.default
  );

  // Listen to download progress
  res.progressStream.listen(
    (progress) {
      print('Downloaded: ${progress.downloaded} bytes');
    },
    onDone: () async {
      print('Download complete');
      print(await outputFile.readAsString());
      await outputFile.delete();
    },
    onError: (error) async {
      print('Download failed: $error');
      if (await outputFile.exists()) await outputFile.delete();
    },
  );
} catch (e) {
  print('Request failed: $e');
}
```
### 2. GET request in memory

```dart
final client = NetworkBoundClient();

try {
  final res = await client.get(
    uri: 'https://example.com/data',
    network: NetworkType.cellular,
  );

  print('Status: ${res.statusCode}');
  print('Response body: ${utf8.decode(res.body)}');
} catch (e) {
  print('Request failed: $e');
}
```


## Notes
- If the **selected network is not available** (for example, requesting cellular network while cellular data is turned off by the OS), the request will wait for a defined interval (connectionTimeout) and then throw a `TimeoutException`.

- If the request is sent to a **network that is active but cannot reach the internet** (for example, a Wi-Fi network without internet access), a `SocketException` will be thrown.

- The **progress stream** is only available when downloading to a file.