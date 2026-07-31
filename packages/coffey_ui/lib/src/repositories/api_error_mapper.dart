import 'package:dio/dio.dart';
import '../models/api_exception.dart';

/// Shared DioException → ApiException translation, used by every repository
/// so error handling stays consistent without repeating the same catch
/// block in each one.
mixin ApiErrorMapper {
  Future<T> guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        throw ApiException(
          statusCode: e.response?.statusCode ?? 0,
          message: data['error'] as String? ?? 'Request failed',
          code: data['code'] as String? ?? 'UNKNOWN',
        );
      }
      throw ApiException(
        statusCode: e.response?.statusCode ?? 0,
        message: 'Network error (${e.type.name}): '
            '${e.message ?? e.error?.toString() ?? 'no further detail'}',
        code: 'NETWORK_ERROR',
      );
    }
  }
}
