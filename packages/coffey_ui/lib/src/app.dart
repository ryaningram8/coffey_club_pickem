import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'blocs/auth/auth_bloc.dart';
import 'blocs/theme/theme_cubit.dart';
import 'repositories/auth_repository.dart';
import 'repositories/game_repository.dart';
import 'repositories/payout_repository.dart';
import 'repositories/pick_repository.dart';
import 'repositories/season_repository.dart';
import 'repositories/standings_repository.dart';
import 'repositories/week_repository.dart';
import 'router/app_router.dart';
import 'services/api_client.dart';
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
  late final AuthBloc _authBloc;
  late final ThemeCubit _themeCubit;
  late final GoRouter _router;

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
    _authBloc = AuthBloc(authRepository: _authRepository)..add(AuthEvent.started());
    _themeCubit = ThemeCubit();
    _router = AppRouter.createRouter(_authBloc);
  }

  @override
  void dispose() {
    _authBloc.close();
    _themeCubit.close();
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
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _authBloc),
          BlocProvider.value(value: _themeCubit),
        ],
        child: BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, themeMode) {
            return MaterialApp.router(
              title: 'Coffey Club Pickem',
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: themeMode,
              routerConfig: _router,
              debugShowCheckedModeBanner: false,
            );
          },
        ),
      ),
    );
  }
}
