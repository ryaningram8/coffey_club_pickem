import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../models/user_model.dart';
import '../../repositories/auth_repository.dart';

part 'auth_bloc.freezed.dart';
part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(const AuthState.initial()) {
    on<AuthStarted>(_onStarted);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthSignupRequested>(_onSignupRequested);
    on<AuthGoogleLoginRequested>(_onGoogleLoginRequested);
    on<AuthGoogleWebSignInSucceeded>(_onGoogleWebSignInSucceeded);
    on<AuthGoogleWebSignInFailed>(_onGoogleWebSignInFailed);
    on<AuthLogoutRequested>(_onLogoutRequested);

    // The rendered web Google button (see widgets/google_web_button.dart)
    // completes sign-in on its own, outside of any bloc-dispatched event —
    // this bridges that into the normal event stream. Guarded to web only:
    // on native, `googleLogin()`'s imperative signIn() call below *also*
    // fires onCurrentUserChanged, which would otherwise double-process it.
    if (kIsWeb) {
      _webGoogleSub = _authRepository.webGoogleSignInResults.listen(
        (user) => add(AuthEvent.googleWebSignInSucceeded(user: user)),
        onError: (Object error) =>
            add(AuthEvent.googleWebSignInFailed(message: error.toString())),
      );
    }
  }

  final AuthRepository _authRepository;
  StreamSubscription<UserModel>? _webGoogleSub;

  @override
  Future<void> close() {
    _webGoogleSub?.cancel();
    return super.close();
  }

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    emit(const AuthState.loading());
    try {
      final user = await _authRepository.getStoredUser();
      emit(
        user != null
            ? AuthState.authenticated(user)
            : const AuthState.unauthenticated(),
      );
    } catch (_) {
      emit(const AuthState.unauthenticated());
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthState.loading());
    try {
      final user = await _authRepository.login(
        email: event.email,
        password: event.password,
      );
      emit(AuthState.authenticated(user));
    } catch (e) {
      emit(AuthState.failure(e.toString()));
    }
  }

  Future<void> _onSignupRequested(
    AuthSignupRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthState.loading());
    try {
      final user = await _authRepository.signup(
        name: event.name,
        email: event.email,
        password: event.password,
        inviteCode: event.inviteCode,
      );
      emit(AuthState.authenticated(user));
    } catch (e) {
      emit(AuthState.failure(e.toString()));
    }
  }

  Future<void> _onGoogleLoginRequested(
    AuthGoogleLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthState.loading());
    try {
      final user = await _authRepository.googleLogin();
      emit(AuthState.authenticated(user));
    } catch (e) {
      emit(AuthState.failure(e.toString()));
    }
  }

  Future<void> _onGoogleWebSignInSucceeded(
    AuthGoogleWebSignInSucceeded event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthState.authenticated(event.user));
  }

  Future<void> _onGoogleWebSignInFailed(
    AuthGoogleWebSignInFailed event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthState.failure(event.message));
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepository.logout();
    emit(const AuthState.unauthenticated());
  }
}
