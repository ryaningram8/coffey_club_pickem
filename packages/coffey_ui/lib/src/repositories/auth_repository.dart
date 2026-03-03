import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/api_exception.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';
import '../services/api_client.dart';
import '../services/token_storage.dart';

class AuthRepository {
  AuthRepository({
    required ApiClient apiClient,
    required TokenStorage tokenStorage,
  })  : _dio = apiClient.dio,
        _tokenStorage = tokenStorage;

  final Dio _dio;
  final TokenStorage _tokenStorage;

  final _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    // Set GOOGLE_CLIENT_ID via --dart-define for web support.
    clientId: const String.fromEnvironment('GOOGLE_CLIENT_ID'),
  );

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _request(() => _dio.post(
          '/auth/login',
          data: {'email': email, 'password': password},
        ));
    final auth = AuthResponseModel.fromJson(response);
    await _persist(auth);
    return auth.user;
  }

  Future<UserModel> signup({
    required String name,
    required String email,
    required String password,
    required String inviteCode,
  }) async {
    final response = await _request(() => _dio.post(
          '/auth/signup',
          data: {
            'name': name,
            'email': email,
            'password': password,
            'inviteCode': inviteCode,
          },
        ));
    final auth = AuthResponseModel.fromJson(response);
    await _persist(auth);
    return auth.user;
  }

  Future<UserModel> googleLogin({String? inviteCode}) async {
    final account = await _googleSignIn.signIn();
    if (account == null) throw Exception('Google sign-in cancelled');

    final googleAuth = await account.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) throw Exception('Google ID token unavailable');

    final response = await _request(() => _dio.post(
          '/auth/google',
          data: {
            'googleToken': idToken,
            if (inviteCode != null) 'inviteCode': inviteCode,
          },
        ));
    final auth = AuthResponseModel.fromJson(response);
    await _persist(auth);
    return auth.user;
  }

  Future<void> logout() async {
    await Future.wait([
      _tokenStorage.clearAll(),
      _googleSignIn.signOut(),
    ]);
  }

  /// Returns the locally-cached user if tokens are still present.
  Future<UserModel?> getStoredUser() async {
    final accessToken = await _tokenStorage.getAccessToken();
    if (accessToken == null) return null;
    return _tokenStorage.getUser();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _request(
    Future<Response<dynamic>> Function() call,
  ) async {
    try {
      final response = await call();
      return response.data as Map<String, dynamic>;
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
        message: e.message ?? 'Network error',
        code: 'NETWORK_ERROR',
      );
    }
  }

  Future<void> _persist(AuthResponseModel auth) async {
    await Future.wait([
      _tokenStorage.saveTokens(
        accessToken: auth.tokens.accessToken,
        refreshToken: auth.tokens.refreshToken,
      ),
      _tokenStorage.saveUser(auth.user),
    ]);
  }
}
