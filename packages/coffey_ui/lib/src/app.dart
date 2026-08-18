import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'blocs/auth/auth_bloc.dart';
import 'blocs/selected_pool/selected_pool_cubit.dart';
import 'blocs/theme/theme_cubit.dart';
import 'repositories/admin_users_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/game_repository.dart';
import 'repositories/invitation_repository.dart';
import 'repositories/notification_repository.dart';
import 'repositories/payout_repository.dart';
import 'repositories/pick_repository.dart';
import 'repositories/season_repository.dart';
import 'repositories/standings_repository.dart';
import 'repositories/week_repository.dart';
import 'router/app_router.dart';
import 'services/api_client.dart';
import 'services/idle_timeout_service.dart';
import 'services/push_notification_service.dart';
import 'services/token_storage.dart';
import 'theme/app_theme.dart';

/// Root application widget shared by both web and mobile entrypoints.
class CoffeyApp extends StatefulWidget {
  const CoffeyApp({super.key});

  @override
  State<CoffeyApp> createState() => _CoffeyAppState();
}

class _CoffeyAppState extends State<CoffeyApp> {
  late final TokenStorage _tokenStorage;
  late final ApiClient _apiClient;
  late final AuthRepository _authRepository;
  late final SeasonRepository _seasonRepository;
  late final WeekRepository _weekRepository;
  late final GameRepository _gameRepository;
  late final PickRepository _pickRepository;
  late final StandingsRepository _standingsRepository;
  late final PayoutRepository _payoutRepository;
  late final NotificationRepository _notificationRepository;
  late final InvitationRepository _invitationRepository;
  late final AdminUsersRepository _adminUsersRepository;
  late final PushNotificationService _pushNotificationService;
  late final AuthBloc _authBloc;
  late final ThemeCubit _themeCubit;
  late final SelectedPoolCubit _selectedPoolCubit;
  late final GoRouter _router;
  IdleTimeoutService? _idleTimeoutService;
  StreamSubscription<AuthState>? _pushRegistrationSubscription;
  StreamSubscription<AuthState>? _selectedPoolSubscription;

  @override
  void initState() {
    super.initState();
    _tokenStorage = TokenStorage();
    _apiClient = ApiClient(_tokenStorage);
    _authRepository = AuthRepository(
      apiClient: _apiClient,
      tokenStorage: _tokenStorage,
    );
    _seasonRepository = SeasonRepository(apiClient: _apiClient);
    _weekRepository = WeekRepository(apiClient: _apiClient);
    _gameRepository = GameRepository(apiClient: _apiClient);
    _pickRepository = PickRepository(apiClient: _apiClient);
    _standingsRepository = StandingsRepository(apiClient: _apiClient);
    _payoutRepository = PayoutRepository(apiClient: _apiClient);
    _notificationRepository = NotificationRepository(apiClient: _apiClient);
    _invitationRepository = InvitationRepository(apiClient: _apiClient);
    _adminUsersRepository = AdminUsersRepository(apiClient: _apiClient);
    _pushNotificationService = PushNotificationService(
      notificationRepository: _notificationRepository,
    );
    _authBloc = AuthBloc(authRepository: _authRepository)..add(AuthEvent.started());
    _themeCubit = ThemeCubit();
    _selectedPoolCubit = SelectedPoolCubit(
      seasonRepository: _seasonRepository,
      invitationRepository: _invitationRepository,
    );
    _router = AppRouter.createRouter(_authBloc);

    if (kIsWeb) {
      _idleTimeoutService = IdleTimeoutService(authBloc: _authBloc)..start();
    }

    _pushRegistrationSubscription = _authBloc.stream.listen((state) {
      if (state is AuthAuthenticated) {
        _pushNotificationService.initialize(_router);
      }
    });

    _selectedPoolSubscription = _authBloc.stream.listen((state) {
      if (state is AuthAuthenticated) {
        _selectedPoolCubit.load(isAdmin: state.user.isAdmin);
      } else if (state is AuthUnauthenticated) {
        _selectedPoolCubit.reset();
      }
    });
  }

  @override
  void dispose() {
    _pushRegistrationSubscription?.cancel();
    _selectedPoolSubscription?.cancel();
    _idleTimeoutService?.dispose();
    _authBloc.close();
    _themeCubit.close();
    _selectedPoolCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: _seasonRepository),
        RepositoryProvider.value(value: _weekRepository),
        RepositoryProvider.value(value: _gameRepository),
        RepositoryProvider.value(value: _pickRepository),
        RepositoryProvider.value(value: _standingsRepository),
        RepositoryProvider.value(value: _payoutRepository),
        RepositoryProvider.value(value: _notificationRepository),
        RepositoryProvider.value(value: _invitationRepository),
        RepositoryProvider.value(value: _adminUsersRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _authBloc),
          BlocProvider.value(value: _themeCubit),
          BlocProvider.value(value: _selectedPoolCubit),
        ],
        child: BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, themeMode) {
            final app = MaterialApp.router(
              title: 'Coffey Club Pickem',
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: themeMode,
              routerConfig: _router,
              debugShowCheckedModeBanner: false,
            );
            // Feeds IdleTimeoutService (web only, no-op elsewhere): any raw
            // pointer activity anywhere in the app resets its timer. Keyboard
            // activity is handled separately inside the service itself via
            // HardwareKeyboard, since that isn't tied to hit-testing here.
            if (_idleTimeoutService == null) return app;
            return Listener(
              onPointerDown: (_) => _idleTimeoutService!.recordActivity(),
              onPointerMove: (_) => _idleTimeoutService!.recordActivity(),
              onPointerSignal: (_) => _idleTimeoutService!.recordActivity(),
              child: app,
            );
          },
        ),
      ),
    );
  }
}
