import 'package:dio/dio.dart';
import '../models/auth_tokens_model.dart';
import 'token_storage.dart';

class ApiClient {
  ApiClient(this._tokenStorage);

  final TokenStorage _tokenStorage;

  static const _baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:4000',
  );

  late final Dio dio = _buildDio();

  Dio _buildDio() {
    final d = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        headers: {'Content-Type': 'application/json'},
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    // Interceptor receives the Dio instance so it can retry requests.
    d.interceptors.add(_AuthInterceptor(_tokenStorage, d));
    return d;
  }
}

class _AuthInterceptor extends QueuedInterceptorsWrapper {
  _AuthInterceptor(this._tokenStorage, this._dio);

  final TokenStorage _tokenStorage;
  final Dio _dio;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      try {
        final refreshToken = await _tokenStorage.getRefreshToken();
        if (refreshToken != null) {
          // Use a bare Dio to avoid running the auth interceptor on the
          // refresh call itself, which would cause recursion.
          final refreshDio = Dio(
            BaseOptions(baseUrl: _dio.options.baseUrl),
          );
          final response = await refreshDio.post(
            '/auth/refresh',
            data: {'refreshToken': refreshToken},
          );
          final tokens = AuthTokensModel.fromJson(
            response.data as Map<String, dynamic>,
          );
          await _tokenStorage.saveTokens(
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
          );

          // Retry the original request; onRequest will attach the new token.
          final retryResponse = await _dio.fetch(err.requestOptions);
          return handler.resolve(retryResponse);
        }
      } catch (_) {
        // Refresh failed — fall through to clear tokens and pass the error on.
      }
      await _tokenStorage.clearAll();
    }

    handler.next(err);
  }
}
