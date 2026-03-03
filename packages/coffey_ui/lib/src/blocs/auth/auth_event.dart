part of 'auth_bloc.dart';

sealed class AuthEvent {}

/// Fired once on app startup to restore session from secure storage.
final class AuthStarted extends AuthEvent {}

final class AuthLoginRequested extends AuthEvent {
  AuthLoginRequested({required this.email, required this.password});
  final String email;
  final String password;
}

final class AuthSignupRequested extends AuthEvent {
  AuthSignupRequested({
    required this.name,
    required this.email,
    required this.password,
    required this.inviteCode,
  });
  final String name;
  final String email;
  final String password;
  final String inviteCode;
}

final class AuthGoogleLoginRequested extends AuthEvent {}

final class AuthLogoutRequested extends AuthEvent {}
