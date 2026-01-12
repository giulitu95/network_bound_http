
import 'network_bound_http_android_platform_interface.dart';

class NetworkBoundHttpAndroid {
  Future<String?> getPlatformVersion() {
    return NetworkBoundHttpAndroidPlatform.instance.getPlatformVersion();
  }
}
