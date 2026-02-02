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
  NetworkBoundClient client = NetworkBoundClient();
  String? content1;
  double? progress1;
  int? statusCode1;

  String? content2;
  double? progress2;
  int? statusCode2;

  void startDownload1() async {
    final path = "${(await getTemporaryDirectory()).path}.tmp";
    final file = File(path);

    late NetworkBoundResponse res;
    try {
      res = await client.get(
        outputFile: File(path),
        uri: "https://proof.ovh.net/files/1Gb.dat",
        network: NetworkType.cellular,
      );
      setState(() {
        statusCode1 = res.statusCode;
      });
      res.progressStream.listen(
        (newProgress) => setState(() {
          progress1 = newProgress;
        }),
        onDone: () async {
          final newContent = await file.readAsString();
          setState(() {
            content1 = newContent;
          });
          await file.delete();
        },
        onError: (e) async {
          // print("error");
          await file.delete();
        },
      );
    } catch (e) {
      // print("tmp");
    }
  }

  void startDownload2() async {
    final path = "${(await getTemporaryDirectory()).path}.tmp";
    final file = File(path);

    late NetworkBoundResponse res;
    try {
      res = await client.get(
        outputFile: File(path),
        uri: "https://proof.ovh.net/files/1Gb.dat",
        network: NetworkType.cellular,
      );
      setState(() {
        statusCode2 = res.statusCode;
      });
      res.progressStream.listen(
        (newProgress) => setState(() {
          progress2 = newProgress;
        }),
        onDone: () async {
          final newContent = await file.readAsString();
          setState(() {
            content2 = newContent;
          });
          await file.delete();
        },
        onError: (e) async {
          // print("error");
          await file.delete();
        },
      );
    } catch (e) {
      // print("tmp");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: startDownload1,
          child: Text('Start Download'),
        ),
        if (progress1 != null) LinearProgressIndicator(value: progress1),
        if (statusCode1 != null) Text(statusCode1.toString()),
        if (content1 != null) Text(content1.toString()),
        SizedBox(height: 10),
        ElevatedButton(
          onPressed: startDownload2,
          child: Text('Start Download'),
        ),
        if (progress2 != null) LinearProgressIndicator(value: progress2),
        if (statusCode2 != null) Text(statusCode1.toString()),
        if (content2 != null) Text(content1.toString()),
      ],
    );
  }
}
