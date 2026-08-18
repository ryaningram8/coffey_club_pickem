import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
        // Web only: makes the browser attach the HttpOnly refresh-token
        // cookie on cross-origin requests (local dev serves the Flutter web
        // app and this API on different ports, i.e. different origins).
        // No-op on mobile.
        extra: {'withCredentials': true},
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
        // Web never has a stored refresh token (see TokenStorage.saveTokens)
        // — it lives only in the HttpOnly cookie the browser sends
        // automatically via withCredentials, so there's nothing to check
        // before attempting refresh. Mobile keeps the original body-token
        // flow, since it's actually persisted in secure storage there.
        final refreshToken = kIsWeb ? null : await _tokenStorage.getRefreshToken();
        if (kIsWeb || refreshToken != null) {
          // Use a bare Dio to avoid running the auth interceptor on the
          // refresh call itself, which would cause recursion.
          final refreshDio = Dio(
            BaseOptions(
              baseUrl: _dio.options.baseUrl,
              extra: {'withCredentials': true},
            ),
          );
          final response = await refreshDio.post(
            '/auth/refresh',
            data: refreshToken != null ? {'refreshToken': refreshToken} : null,
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
