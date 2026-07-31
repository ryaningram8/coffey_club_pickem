class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.message,
    required this.code,
  });

  final int statusCode;
  final String message;
  final String code;

  bool get isUnauthorized => statusCode == 401;
  bool get isConflict => statusCode == 409;
  bool get isNotFound => statusCode == 404;

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}
