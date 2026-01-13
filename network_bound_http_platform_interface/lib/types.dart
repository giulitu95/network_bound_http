enum NetworkType {
  any,
  wifi,
  cellular,
}


class NetworkBoundHttpEvent {
  final int downloaded;
  final int total;

  NetworkBoundHttpEvent({required this.downloaded, required this.total});

  double get percent =>
      total > 0 ? downloaded / total : 0;
}

