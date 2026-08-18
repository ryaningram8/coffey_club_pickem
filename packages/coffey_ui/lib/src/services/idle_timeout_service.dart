import 'dart:async';
import 'package:flutter/services.dart';
import '../blocs/auth/auth_bloc.dart';

/// Signs the user out after a period of no interaction. Web only — mobile
/// already has OS-level lock screen/biometric protection, and auto-logging
/// someone out of the mobile app just for not touching the screen for a
/// while would be a UX regression with no matching security benefit. This
/// exists to close the web-specific "walked away from a shared/public
/// computer with the tab still open" gap.
///
/// Activity is tracked two ways: raw pointer events (see the [Listener] this
/// is wired to in app.dart) for taps/clicks/scrolls/mouse movement, and
/// [HardwareKeyboard] for keystrokes — the latter is a global handler, not
/// tied to a specific focused widget, so it catches typing anywhere in the
/// app.
class IdleTimeoutService {
  IdleTimeoutService({
    required AuthBloc authBloc,
    this.timeout = const Duration(minutes: 30),
  }) : _authBloc = authBloc;

  final AuthBloc _authBloc;
  final Duration timeout;

  Timer? _timer;
  StreamSubscription<AuthState>? _authSubscription;

  void start() {
    _authSubscription = _authBloc.stream.listen(_onAuthStateChanged);
    _onAuthStateChanged(_authBloc.state);
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
  }

  void dispose() {
    _authSubscription?.cancel();
    _timer?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
  }

  /// Called from app.dart's top-level [Listener] on any pointer event.
  void recordActivity() {
    // Only track while a session is actually active — nothing to time out
    // on the login screen.
    if (_timer != null) _resetTimer();
  }

  bool _onKeyEvent(KeyEvent event) {
    recordActivity();
    return false; // don't consume/block the event
  }

  void _onAuthStateChanged(AuthState state) {
    if (state is AuthAuthenticated) {
      _resetTimer();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    _timer = Timer(timeout, _onTimeout);
  }

  void _onTimeout() {
    _authBloc.add(const AuthEvent.logoutRequested());
  }
}
