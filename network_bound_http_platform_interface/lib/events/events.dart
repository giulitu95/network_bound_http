enum NetworkType {
  standard,
  wifi,
  cellular,
}


sealed class NetworkBoundHttpEvent{
  final String id;

  NetworkBoundHttpEvent({required this.id});

}

class ProgressHttpEvent extends NetworkBoundHttpEvent{
  final int downloaded;
  final int total;

  ProgressHttpEvent({
    required super.id,
    required this.downloaded,
    required this.total,
  });

  factory ProgressHttpEvent.fromRawEvent({required Map<String, dynamic> e}){
    return ProgressHttpEvent(
      id: e["id"],
      downloaded: e["downloaded"],
      total: e["total"]
    );
  }

  double get percent =>
      total > 0 ? downloaded / total : 0;
}

class CompleteHttpEvent extends NetworkBoundHttpEvent{
  final int statusCode;
  final Map<String, String> headers;
  final String outputPath;

  factory CompleteHttpEvent.fromRawEvent({required Map<String, dynamic> e}){
    return CompleteHttpEvent(
      id: e["id"],
      statusCode: e["statusCode"],
      headers: e["headers"] ,
      outputPath: e["outputPath"],
    );
  }
  
  CompleteHttpEvent({
    required super.id,
    required this.statusCode,
    required this.headers,
    required this.outputPath
  });

}

