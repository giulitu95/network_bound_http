import 'dart:io';

import 'package:flutter/material.dart';
import 'package:network_bound_http/http_request.dart';
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
  String? content;

  double? progress;
  int? statusCode;

  void startDownload() async {
    final path = "${(await getTemporaryDirectory()).path}.tmp";
    final file = File(path);
    NbHttpRequest request = NbHttpRequest(
      uri: "https://example.com",
      outputPath: path,
    );
    final res = await request.sendRequest();
    setState(() {
      statusCode = res.statusCode;
    });
    res.progressStream
        .listen(
          (newProgress) => setState(() {
            progress = newProgress;
          }),
        )
        .onDone(() async {
          final newContent = await file.readAsString();
          setState(() {
            content = newContent;
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(onPressed: startDownload, child: Text('Start Download')),
        if (progress != null) LinearProgressIndicator(value: progress),
        if (statusCode != null) Text(statusCode.toString()),
        if (content != null) Text(content.toString()),
      ],
    );
  }
}
