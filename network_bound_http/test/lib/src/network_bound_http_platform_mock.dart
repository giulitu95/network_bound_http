import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_bound_http_platform_interface/network_bound_http_platform_interface.dart';

class NetworkBoundHttpPlatformMock extends Fake
    implements NetworkBoundHttpPlatform {
  Stream<Map<String, dynamic>>? callbackStreamOutput;
  bool isCallbackStreamCalled = false;

  Map<String, dynamic>? requestInput;
  String? sendRequestOutput;

  @override
  Stream<Map<String, dynamic>> get callbackStream {
    isCallbackStreamCalled = true;
    assert(callbackStreamOutput != null);
    return callbackStreamOutput!;
  }

  @override
  Future<String?> sendRequest({required Map<String, dynamic> request}) async {
    assert(requestInput != null);
    expect(
      const DeepCollectionEquality.unordered().equals(request, requestInput),
      isTrue,
    );
    return sendRequestOutput;
  }
}
