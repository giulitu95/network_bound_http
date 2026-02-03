import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_bound_http_platform_interface/network_bound_http_platform_interface.dart';

class NetworkBoundHttpPlatformMock extends Fake
    implements NetworkBoundHttpPlatform {
  Stream<Map<String, dynamic>>? callbackStreamOutput;
  bool isCallbackStreamCalled = false;

  List<Map<String, dynamic>> requestInputs = [];
  int sendRequestCallCounter = 0;

  @override
  Stream<Map<String, dynamic>> get callbackStream {
    isCallbackStreamCalled = true;
    assert(callbackStreamOutput != null);
    return callbackStreamOutput!;
  }

  @override
  Future<String?> sendRequest({required Map<String, dynamic> request}) async {
    expect(
      const DeepCollectionEquality.unordered().equals(
        request,
        requestInputs[sendRequestCallCounter],
      ),
      isTrue,
    );
    sendRequestCallCounter++;
    return null;
  }
}
