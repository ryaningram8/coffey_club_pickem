import 'package:google_sign_in/google_sign_in.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';
import '../services/api/auth_api.dart';
import '../services/api_client.dart';
import '../services/token_storage.dart';
import 'api_error_mapper.dart';

class AuthRepository with ApiErrorMapper {
  AuthRepository({
    required ApiClient apiClient,
    required TokenStorage tokenStorage,
  })  : _authApi = AuthApi(apiClient.dio),
        _tokenStorage = tokenStorage;

  final AuthApi _authApi;
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
    final auth = await guard(
      () => _authApi.login({'email': email, 'password': password}),
    );
    await _persist(auth);
    return auth.user;
  }

  Future<UserModel> signup({
    required String name,
    required String email,
    required String password,
    required String inviteCode,
  }) async {
    final auth = await guard(
      () => _authApi.signup({
        'name': name,
        'email': email,
        'password': password,
        'inviteCode': inviteCode,
      }),
    );
    await _persist(auth);
    return auth.user;
  }

  Future<UserModel> googleLogin({String? inviteCode}) async {
    final account = await _googleSignIn.signIn();
    if (account == null) throw Exception('Google sign-in cancelled');

    final googleAuth = await account.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) throw Exception('Google ID token unavailable');

    final auth = await guard(
      () => _authApi.googleAuth({
        'googleToken': idToken,
        'inviteCode': ?inviteCode,
      }),
    );
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
