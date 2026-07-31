import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import '../blocs/auth/auth_bloc.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/commissioner/commissioner_home_screen.dart';
import '../screens/commissioner/commissioner_week_screen.dart';
import '../screens/commissioner/game_browser_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/picks/pick_sheet_screen.dart';
import '../screens/settings/settings_screen.dart';
import 'app_routes.dart';

class AppRouter {
  AppRouter._();

  /// Creates a [GoRouter] wired to [authBloc] for auth-guarded navigation.
  static GoRouter createRouter(AuthBloc authBloc) {
    final notifier = _AuthNotifier(authBloc);
    return GoRouter(
      initialLocation: AppRoutes.login,
      refreshListenable: notifier,
      redirect: (context, state) => _guard(authBloc, state),
      routes: [
        // Auth
        GoRoute(
          path: AppRoutes.login,
          name: 'login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: AppRoutes.signup,
          name: 'signup',
          builder: (context, state) => SignupScreen(
            inviteCode: state.uri.queryParameters['code'],
          ),
        ),

        // Player
        GoRoute(
          path: AppRoutes.home,
          name: 'home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: AppRoutes.pickSheet,
          name: 'pickSheet',
          builder: (context, state) => PickSheetScreen(
            weekId: state.pathParameters['weekId']!,
          ),
        ),
        GoRoute(
          path: AppRoutes.settings,
          name: 'settings',
          builder: (context, state) => const SettingsScreen(),
        ),

        // Commissioner
        GoRoute(
          path: AppRoutes.commissioner,
          name: 'commissioner',
          builder: (context, state) => const CommissionerHomeScreen(),
        ),
        GoRoute(
          path: AppRoutes.commissionerWeek,
          name: 'commissionerWeek',
          builder: (context, state) => CommissionerWeekScreen(
            weekId: state.pathParameters['weekId']!,
          ),
        ),
        GoRoute(
          path: AppRoutes.commissionerGames,
          name: 'commissionerGames',
          builder: (context, state) => GameBrowserScreen(
            weekId: state.pathParameters['weekId']!,
          ),
        ),

        // TODO: Add remaining routes as screens are built (Phase 3+)
      ],
    );
  }

  static String? _guard(AuthBloc authBloc, GoRouterState state) {
    final isAuthenticated = authBloc.state is AuthAuthenticated;
    final isInitial = authBloc.state is AuthInitial;
    final isLoading = authBloc.state is AuthLoading;

    // While auth state is resolving, don't redirect yet.
    if (isInitial || isLoading) return null;

    final isAuthRoute = state.matchedLocation == AppRoutes.login ||
        state.matchedLocation == AppRoutes.signup;

    if (!isAuthenticated && !isAuthRoute) return AppRoutes.login;
    if (isAuthenticated && isAuthRoute) return AppRoutes.home;
    return null;
  }
}

/// Listens to [AuthBloc] stream and notifies [GoRouter] to re-evaluate guards
/// whenever auth state changes.
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(AuthBloc authBloc) {
    _subscription = authBloc.stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
