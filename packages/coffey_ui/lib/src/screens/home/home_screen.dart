import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/home_hero/home_hero_cubit.dart';
import '../../blocs/selected_pool/selected_pool_cubit.dart';
import '../../models/season_model.dart';
import '../../models/user_model.dart';
import '../../repositories/pick_repository.dart';
import '../../repositories/season_repository.dart';
import '../../repositories/standings_repository.dart';
import '../../repositories/week_repository.dart';
import '../../widgets/coffey_logo.dart';
import '../../widgets/home_hero_card.dart';
import '../../widgets/pool_switcher_bar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;
    final poolState = context.watch<SelectedPoolCubit>().state;

    SeasonModel? selectedPool;
    if (poolState is SelectedPoolLoaded) {
      for (final pool in poolState.pools) {
        if (pool.id == poolState.selectedPoolId) {
          selectedPool = pool;
          break;
        }
      }
    }
    final isCommissioner = (user?.isAdmin ?? false) || selectedPool?.myRole == 'commissioner';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CoffeyLogo(height: 32),
            SizedBox(width: 10),
            Text('Coffey Club Pickem'),
          ],
        ),
        actions: [
          if (user?.isAdmin ?? false) ...[
            IconButton(
              icon: const Icon(Icons.mail_outline),
              tooltip: 'Manage Invites',
              onPressed: () => context.pushNamed('commissionerInvites'),
            ),
            IconButton(
              icon: const Icon(Icons.people_outline),
              tooltip: 'Manage Users',
              onPressed: () => context.pushNamed('adminUsers'),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.pushNamed('settings'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => context.read<AuthBloc>().add(const AuthEvent.logoutRequested()),
          ),
        ],
        bottom: user == null
            ? null
            : const PreferredSize(
                preferredSize: Size.fromHeight(PoolSwitcherBar.height),
                child: PoolSwitcherBar(),
              ),
      ),
      body: user == null || poolState is! SelectedPoolLoaded
          ? _HomeBody(user: user, seasonId: null, isCommissioner: isCommissioner)
          : BlocProvider(
              key: ValueKey(poolState.selectedPoolId),
              create: (context) => HomeHeroCubit(
                weekRepository: context.read<WeekRepository>(),
                seasonRepository: context.read<SeasonRepository>(),
                standingsRepository: context.read<StandingsRepository>(),
                pickRepository: context.read<PickRepository>(),
                currentUserId: user.id,
                seasonId: poolState.selectedPoolId,
              ),
              child: _HomeBody(
                user: user,
                seasonId: poolState.selectedPoolId,
                isCommissioner: isCommissioner,
              ),
            ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.user,
    required this.seasonId,
    required this.isCommissioner,
  });

  final UserModel? user;

  /// The currently selected pool, from SelectedPoolCubit — null while it's
  /// still loading, empty (no pools joined), or failed, in which case the
  /// pool switcher bar in the header already explains why and this just
  /// shows a lightweight placeholder instead of pool-scoped actions.
  final String? seasonId;

  final bool isCommissioner;

  @override
  Widget build(BuildContext context) {
    Widget content = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (user != null) ...[
                Text(
                  'Signed in as ${user!.name}${user!.isAdmin ? ' (Admin)' : ''}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
              if (user != null && seasonId != null) ...[
                BlocBuilder<HomeHeroCubit, HomeHeroState>(
                  builder: (context, state) => HomeHeroCard(state: state),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _openCurrentWeek(context, seasonId!, 'pickSheet'),
                  icon: const Icon(Icons.checklist),
                  label: const Text("This Week's Picks"),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _openCurrentWeek(context, seasonId!, 'liveResults'),
                  icon: const Icon(Icons.live_tv_outlined),
                  label: const Text('Live Results'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _openCurrentWeek(context, seasonId!, 'weeklyStandings'),
                  icon: const Icon(Icons.leaderboard_outlined),
                  label: const Text('Weekly Standings'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.pushNamed('seasonStandings'),
                  icon: const Icon(Icons.emoji_events_outlined),
                  label: const Text('Season Standings'),
                ),
                if (isCommissioner) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => context.pushNamed('commissioner'),
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    label: const Text('Commissioner Dashboard'),
                  ),
                ],
              ] else if (user != null) ...[
                const Text(
                  'Pick a pool above to get started.',
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (user != null && seasonId != null) {
      content = RefreshIndicator(
        onRefresh: () => context.read<HomeHeroCubit>().load(),
        child: content,
      );
    }

    return SafeArea(child: content);
  }

  Future<void> _openCurrentWeek(BuildContext context, String seasonId, String routeName) async {
    final weekRepository = context.read<WeekRepository>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final week = await weekRepository.getCurrentWeek(seasonId);
      if (week == null) {
        messenger.showSnackBar(const SnackBar(content: Text('No active week yet.')));
        return;
      }
      if (!context.mounted) return;
      context.pushNamed(routeName, pathParameters: {'weekId': week.id});
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not load current week: $e')));
    }
  }
}
