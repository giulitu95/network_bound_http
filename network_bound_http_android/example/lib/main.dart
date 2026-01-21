import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:network_bound_http_android/network_bound_http_android.dart';
import 'package:network_bound_http_platform_interface/types.dart';
import 'package:path_provider/path_provider.dart';
import 'package:downloads_path_provider_28/downloads_path_provider_28.dart';

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
            Directory? downloadDir = await DownloadsPathProvider.downloadsDirectory;
            _networkBoundHttpAndroidPlugin.sendHttpRequest(
                uri: "https://graph.microsoft.com/v1.0/sites/faegroupspa.sharepoint.com,ed31c769-fccc-45f2-a187-3a233ae509e9,fcc669a6-dda7-4198-95cf-b334978c7838/drive/root:/assets/applicationFiles/BL2_EX_1_5_0_0.lhx:/content",
                headers: {
                  'Authorization': 'Bearer eyJ0eXAiOiJKV1QiLCJub25jZSI6Ikg3NlY4UzZDaUoyc0hxWTF6aWJxcmIzUUd0VDBGNkJJUjZZME9tUmtvWmsiLCJhbGciOiJSUzI1NiIsIng1dCI6IlBjWDk4R1g0MjBUMVg2c0JEa3poUW1xZ3dNVSIsImtpZCI6IlBjWDk4R1g0MjBUMVg2c0JEa3poUW1xZ3dNVSJ9.eyJhdWQiOiJodHRwczovL2dyYXBoLm1pY3Jvc29mdC5jb20iLCJpc3MiOiJodHRwczovL3N0cy53aW5kb3dzLm5ldC82MDFmMDE3Yi1iNWJjLTQyZDItYjIyZS1hMTlkZjlhMTA5OTEvIiwiaWF0IjoxNzY4OTkwNzI2LCJuYmYiOjE3Njg5OTA3MjYsImV4cCI6MTc2ODk5NDYyNiwiYWlvIjoiazJaZ1lQajY1KzI3MDdJUk00dmowMjNYeG9Sc0JRQT0iLCJhcHBfZGlzcGxheW5hbWUiOiJGRFQgR3JhcGggQVBJIiwiYXBwaWQiOiJhYWViZDNlOS0yM2ZkLTRlYWMtYjhhZC04ZTIxYTFlMmJjMzUiLCJhcHBpZGFjciI6IjEiLCJpZHAiOiJodHRwczovL3N0cy53aW5kb3dzLm5ldC82MDFmMDE3Yi1iNWJjLTQyZDItYjIyZS1hMTlkZjlhMTA5OTEvIiwiaWR0eXAiOiJhcHAiLCJvaWQiOiI4YTc5MDdlMC1mMzI1LTQ0MDItOTc3NC1mOGYzN2I0ZGJiNzUiLCJyaCI6IjEuQVZ3QWV3RWZZTHkxMGtLeUxxR2QtYUVKa1FNQUFBQUFBQUFBd0FBQUFBQUFBQURuQUFCY0FBLiIsInJvbGVzIjpbIlNpdGVzLlNlbGVjdGVkIiwiRGV2aWNlTWFuYWdlbWVudFNlcnZpY2VDb25maWcuUmVhZFdyaXRlLkFsbCIsIkZpbGVzLlJlYWQuQWxsIiwiRGV2aWNlTWFuYWdlbWVudE1hbmFnZWREZXZpY2VzLlJlYWRXcml0ZS5BbGwiLCJEZXZpY2VNYW5hZ2VtZW50Q29uZmlndXJhdGlvbi5SZWFkV3JpdGUuQWxsIiwiRGV2aWNlTWFuYWdlbWVudEFwcHMuUmVhZFdyaXRlLkFsbCJdLCJzdWIiOiI4YTc5MDdlMC1mMzI1LTQ0MDItOTc3NC1mOGYzN2I0ZGJiNzUiLCJ0ZW5hbnRfcmVnaW9uX3Njb3BlIjoiRVUiLCJ0aWQiOiI2MDFmMDE3Yi1iNWJjLTQyZDItYjIyZS1hMTlkZjlhMTA5OTEiLCJ1dGkiOiJNREFLZmRTci0wdVFGWTlUUWgwVEFBIiwidmVyIjoiMS4wIiwid2lkcyI6WyIwOTk3YTFkMC0wZDFkLTRhY2ItYjQwOC1kNWNhNzMxMjFlOTAiXSwieG1zX2FjZCI6MTczOTM3MDI3NiwieG1zX2FjdF9mY3QiOiIzIDkiLCJ4bXNfZnRkIjoiSEdZX0h4Vi1Nbkk4cjNreHVDUlF0ZENNdkxrUDJxOGpJWXppVTRkdVIzd0JabkpoYm1ObFl5MWtjMjF6IiwieG1zX2lkcmVsIjoiNyA0IiwieG1zX3JkIjoiMC40MkxsWUJKaWpCRVM0V0FYRW5oNS1zSDlfWHVzZlJkX09CXzNyblgyU2FBb3A1REFwN2xCS3Z6VGlqeTd2SGJLc1U1OHNRb295aUVrd013QUFRZWdOQUEiLCJ4bXNfc3ViX2ZjdCI6IjMgOSIsInhtc190Y2R0IjoxNTg2OTY2NzE1LCJ4bXNfdGRiciI6IkVVIiwieG1zX3RudF9mY3QiOiIzIDYifQ.Lkm70_M6XychdQtx8bvowHqrPfly7Se5945kSl889gM-MX7KnT8qH4B1FpsjXiqjsLYn5nN9MmbQIuLh5F35cMy_5OzHR22wYPT1MbRM01icWS4mZ7IYiwvyVLcF88VvlRTbej215JXfG_QYWexY51JJDp8QdwhmZN_RoFNzLHXFgOKnkhcDR12cnWHCjD_lKqhf62evW5jNm0Sr70k8MtvqZFD4N0NpLWTv_Oqmqgl8TVvg4HCamHG6-rlGI9ZjwQEnlVRdvp0ZSHH6rfn-8XGEvl9fOuwsSnnZ8O8iUiEytVhnhIxQnvPWFXqXYT64Y5VYBWu5k8HPfLxjyidJrA',
                  'Accept': 'application/json'
                },
                method: "GET",
                outputPath: "${downloadDir?.path}/tmp.lhx",
                network: NetworkType.standard).listen((data) async {
                  print("--------------");
                  if(data is CompleteHttpEvent){
                    print(data.statusCode);
                    final downlaoded = File("${downloadDir?.path}/tmp.lhx");
                    if (await downlaoded.exists()) {
                      print('File esiste');
                    }
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
