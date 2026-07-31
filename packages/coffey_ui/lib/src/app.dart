import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'blocs/auth/auth_bloc.dart';
import 'repositories/auth_repository.dart';
import 'repositories/game_repository.dart';
import 'repositories/pick_repository.dart';
import 'repositories/season_repository.dart';
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
  late final AuthBloc _authBloc;
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
    _authBloc = AuthBloc(authRepository: _authRepository)..add(AuthEvent.started());
    _router = AppRouter.createRouter(_authBloc);
  }

  @override
  void dispose() {
    _authBloc.close();
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
      ],
      child: BlocProvider.value(
        value: _authBloc,
        child: MaterialApp.router(
          title: 'Coffey Club Pickem',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.system,
          routerConfig: _router,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
