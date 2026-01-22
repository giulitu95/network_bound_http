import 'package:network_bound_http_platform_interface/events/events.dart';

class EventFactory {
  NetworkBoundHttpEvent createFromMap(Map<String, dynamic> rawEvent) {
    switch (rawEvent["type"]) {
      case "progress":
        return ProgressHttpEvent(
          id: rawEvent["id"],
          downloaded: rawEvent["downloaded"],
          total: rawEvent["total"],
        );
      case "complete":
        return CompleteHttpEvent(
            id: rawEvent["id"],
            statusCode: rawEvent["statusCode"],
            headers: rawEvent["headers"],
            outputPath: rawEvent["outputPath"]);
      default:
        throw UnimplementedError();
    }
  }
}
