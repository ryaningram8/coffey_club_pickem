import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/home/home_screen.dart';
import 'app_routes.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.home,
    redirect: _authGuard,
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
        builder: (context, state) => const SignupScreen(),
      ),

      // Player
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),

      // TODO: Add remaining routes as screens are built (Phase 2+)
    ],
  );

  /// Redirects unauthenticated users to login.
  /// Token presence check will be replaced with AuthBloc listener in Phase 2.
  static String? _authGuard(BuildContext context, GoRouterState state) {
    // Placeholder — full auth guard wired in Phase 2 when AuthBloc is ready.
    return null;
  }
}
