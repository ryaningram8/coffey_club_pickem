part of 'auth_bloc.dart';

@freezed
class AuthEvent with _$AuthEvent {
  /// Fired once on app startup to restore session from secure storage.
  const factory AuthEvent.started() = AuthStarted;

  const factory AuthEvent.loginRequested({
    required String email,
    required String password,
  }) = AuthLoginRequested;

  const factory AuthEvent.signupRequested({
    required String name,
    required String email,
    required String password,
    required String inviteCode,
  }) = AuthSignupRequested;

  const factory AuthEvent.googleLoginRequested() = AuthGoogleLoginRequested;

  const factory AuthEvent.logoutRequested() = AuthLogoutRequested;
}
