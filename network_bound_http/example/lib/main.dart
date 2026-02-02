import 'dart:io';

import 'package:flutter/material.dart';
import 'package:network_bound_http/network_bound_http.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('NetworkBoundHttp Example')),
        body: _DownloadWidget(),
      ),
    );
  }
}

class _DownloadWidget extends StatefulWidget {
  const _DownloadWidget();

  @override
  _DownloadWidgetState createState() => _DownloadWidgetState();
}

class _DownloadWidgetState extends State<_DownloadWidget> {
  final TextEditingController uriController = TextEditingController(
    text: "https://example.com/",
  );

  NetworkBoundClient client = NetworkBoundClient();
  String? content;
  String? error;
  double? progress;
  int? statusCode;
  NetworkType networkType = NetworkType.standard;

  void startDownload1(NetworkType network) async {
    final path = "${(await getTemporaryDirectory()).path}.tmp";
    final file = File(path);

    late NetworkBoundResponse res;
    try {
      res = await client.get(
        outputFile: File(path),
        uri: uriController.text,
        network: network,
      );
      setState(() {
        statusCode = res.statusCode;
      });
      res.progressStream.listen(
        (newProgress) => setState(() {
          progress = newProgress.contentLength != null
              ? newProgress.downloaded / newProgress.contentLength!
              : null;
        }),
        onDone: () async {
          final newContent = await file.readAsString();
          setState(() {
            content = newContent;
          });
          await file.delete();
        },
        onError: (e) async {
          setState(() {
            error = "Failed to fetch data: $e";
          });
          await file.delete();
        },
      );
    } catch (e) {
      setState(() {
        error = "Failed to send request: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: TextField(controller: uriController)),
              SizedBox(width: 10),
              if (progress != null) CircularProgressIndicator(value: progress),
            ],
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              startDownload1(networkType);
            },
            child: Text('Start Download'),
          ),
          SizedBox(height: 5),
          SegmentedButton<NetworkType>(
            segments: [
              ButtonSegment(
                value: NetworkType.standard,
                label: Text("Default"),
              ),
              ButtonSegment(value: NetworkType.wifi, label: Text("Wifi")),
              ButtonSegment(
                value: NetworkType.cellular,
                label: Text("Cellular"),
              ),
            ],
            selected: {networkType},
            onSelectionChanged: (s) => setState(() => networkType = s.first),
          ),
          SizedBox(height: 20),
          if (statusCode != null || error != null)
            Expanded(
              child: Card.outlined(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: ListView(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Response",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                error = null;
                                content = null;
                                statusCode = null;
                                progress = null;
                              });
                            },
                            icon: Icon(Icons.delete),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            "Status code: ",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(statusCode.toString()),
                        ],
                      ),
                      SizedBox(height: 10),
                      if (content != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Body:",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(content.toString()),
                          ],
                        ),
                      SizedBox(height: 10),
                      if (error != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Error:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            Text(error.toString()),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
