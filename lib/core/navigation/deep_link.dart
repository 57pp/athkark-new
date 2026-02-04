class DeepLink {
  DeepLink({
    required this.route,
    Map<String, String>? query,
  }) : query = Map<String, String>.from(query ?? const <String, String>{});

  final String route;
  final Map<String, String> query;

  String? operator [](String key) => query[key];
}
