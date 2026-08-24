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

  /// Bridges AuthRepository.webGoogleSignInResults (see auth_bloc.dart's
  /// constructor) into the normal event->emit flow — the web Google button
  /// completes outside of any bloc-dispatched event, so this is how its
  /// result reaches state.
  const factory AuthEvent.googleWebSignInSucceeded({required UserModel user}) =
      AuthGoogleWebSignInSucceeded;

  const factory AuthEvent.googleWebSignInFailed({required String message}) =
      AuthGoogleWebSignInFailed;

  const factory AuthEvent.logoutRequested() = AuthLogoutRequested;
}
