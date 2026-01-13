import 'dart:io';
import 'package:flutter/material.dart';
import 'package:network_bound_http/network_bound_http.dart';


void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
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
  double progress = 0;
  String? filePath;
  String? error;

  void startDownload() {
    final stream = NetworkBoundHttp.download(
      url: "https://example.com/file.bin",
      network: NetworkType.cellular,
    );


    stream.listen((event) {
      if (event is DownloadProgress) {
        setState(() {
          progress = event.percent;
        });
      } else if (event is DownloadComplete) {
        setState(() {
          filePath = event.path;
        });
      } else if (event is DownloadError) {
        setState(() {
          error = event.message;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: startDownload,
          child: Text('Start Download'),
        ),
        if (progress > 0 && progress < 1)
          Text("Progress: ${(progress * 100).toStringAsFixed(1)}%"),
        if (filePath != null) Text("Saved at $filePath"),
        if (error != null) Text("Error: $error"),
      ],
    );
  }
}
