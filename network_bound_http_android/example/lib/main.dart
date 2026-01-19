import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:network_bound_http_android/network_bound_http_android.dart';
import 'package:network_bound_http_platform_interface/types.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _networkBoundHttpAndroidPlugin = NetworkBoundHttpAndroid();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;


  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: OutlinedButton(onPressed: () async {
            final dir = await getApplicationDocumentsDirectory();
            _networkBoundHttpAndroidPlugin.sendHttpRequest(
                uri: "https://httpbin.org/get",
                method: "GET",
                outputPath: "${dir.path}/tmp",
                network: NetworkType.any).listen((data) async {
                  print("--------------");
                  if(data is CompleteHttpEvent){
                    final file = File(data.outputPath);
                    final content = await file.readAsString();
                    print(content);
                  } else if (data is ProgressHttpEvent){
                    print("${(data.downloaded / data.total) * 100} %");
                  }

            }, onError: (e){
                  print("error: ${e.code}");
            }, onDone: (){
                  print("done");
            });
          }, child: Text("Send http request")),
        ),
      ),
    );
  }
}
