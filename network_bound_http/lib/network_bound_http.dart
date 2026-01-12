
import 'network_bound_http_platform_interface.dart';

class NetworkBoundHttp {
  Future<String?> getPlatformVersion() {
    return NetworkBoundHttpPlatform.instance.getPlatformVersion();
  }
}
