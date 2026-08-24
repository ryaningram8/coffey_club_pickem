import 'package:flutter/foundation.dart' show kIsWeb;
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
    // Ensures the ID token's audience matches the backend's GOOGLE_CLIENT_ID
    // on Android/iOS too, where `clientId` above is otherwise ignored.
    // google_sign_in_web asserts serverClientId == null on web — must be
    // omitted there, or plugin init fails (silently, since it's unawaited).
    serverClientId: kIsWeb ? null : const String.fromEnvironment('GOOGLE_CLIENT_ID'),
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
    return _completeGoogleSignIn(account, inviteCode: inviteCode);
  }

  /// Web sign-ins complete via GIS's rendered button (see
  /// widgets/google_web_button.dart) rather than an imperative call — the
  /// button click itself drives `_googleSignIn.onCurrentUserChanged`, so
  /// LoginScreen listens to this instead of calling `googleLogin()`.
  Stream<UserModel> get webGoogleSignInResults => _googleSignIn
      .onCurrentUserChanged
      .where((account) => account != null)
      .asyncMap((account) => _completeGoogleSignIn(account!));

  Future<UserModel> _completeGoogleSignIn(
    GoogleSignInAccount account, {
    String? inviteCode,
  }) async {
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
      // Best-effort: an unguarded failure here (e.g. the web GIS plugin
      // throwing) would reject the whole Future.wait and skip emitting
      // AuthState.unauthenticated — local logout must succeed regardless.
      _googleSignIn.signOut().catchError((_) => null),
      // Best-effort: on web this clears the HttpOnly refresh cookie
      // server-side (nothing client-side can touch it directly). A failure
      // here shouldn't block local logout — worst case the cookie outlives
      // the session until it naturally expires.
      _authApi.logout().catchError((_) {}),
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
