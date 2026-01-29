sealed class NetworkBoundHttpEvent {
  final String id;

  NetworkBoundHttpEvent({required this.id});
}

class ProgressHttpEvent extends NetworkBoundHttpEvent {
  final int downloaded;
  final int total;

  ProgressHttpEvent({
    required super.id,
    required this.downloaded,
    required this.total,
  });

  double get percent => total > 0 ? downloaded / total : 0;
}

class CompleteHttpEvent extends NetworkBoundHttpEvent {
  final int statusCode;
  final Map<dynamic, dynamic> headers;
  final String outputPath;

  CompleteHttpEvent({
    required super.id,
    required this.statusCode,
    required this.headers,
    required this.outputPath,
  });
}

class ErrorHttpEvent extends NetworkBoundHttpEvent {
  final String message;
  ErrorHttpEvent({required super.id, required this.message});
}
