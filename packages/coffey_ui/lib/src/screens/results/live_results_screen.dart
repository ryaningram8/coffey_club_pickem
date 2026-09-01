import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/live_results/live_results_bloc.dart';
import '../../models/pick_summary_model.dart';
import '../../repositories/standings_repository.dart';
import '../../repositories/week_repository.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/error_state_view.dart';
import '../../widgets/live_game_card.dart';
import '../../widgets/live_leaderboard.dart';
import '../../widgets/responsive_content.dart';
import '../../widgets/skeleton_loaders.dart';

class LiveResultsScreen extends StatelessWidget {
  const LiveResultsScreen({super.key, required this.weekId});

  final String weekId;

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final currentUserId = authState is AuthAuthenticated
        ? authState.user.id
        : '';

    return BlocProvider(
      create: (context) => LiveResultsBloc(
        weekRepository: context.read<WeekRepository>(),
        standingsRepository: context.read<StandingsRepository>(),
        weekId: weekId,
      )..add(const LiveResultsEvent.started()),
      child: _LiveResultsView(currentUserId: currentUserId, weekId: weekId),
    );
  }
}

class _LiveResultsView extends StatelessWidget {
  const _LiveResultsView({required this.currentUserId, required this.weekId});

  final String currentUserId;
  final String weekId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Results')),
      body: BlocBuilder<LiveResultsBloc, LiveResultsState>(
        builder: (context, state) {
          if (state is LiveResultsInitial || state is LiveResultsLoading) {
            return const SkeletonGameCardList();
          }
          if (state is LiveResultsFailure) {
            return ErrorStateView(
              message: 'Could not load live results: ${state.message}',
              onRetry: () => context.read<LiveResultsBloc>().add(
                const LiveResultsEvent.started(),
              ),
            );
          }
          if (state is LiveResultsLoaded) {
            final games = state.week.games;
            final myEntry = _findEntry(state.picksSummary, currentUserId);
            final myPicks = {
              for (final p in myEntry?.picks ?? <PickSummaryItemModel>[])
                p.gameId: p,
            };
            final myCorrectCount = myPicks.values
                .where((p) => p.isCorrect == true)
                .length;
            final leaderboard = _buildLeaderboard(state.picksSummary);

            if (games.isEmpty) {
              return const EmptyStateView(
                icon: Icons.live_tv_outlined,
                message: 'No games assigned for this week yet.',
              );
            }

            return RefreshIndicator(
              onRefresh: () async => context.read<LiveResultsBloc>().add(
                const LiveResultsEvent.refreshed(),
              ),
              child: ResponsiveContent(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'You: $myCorrectCount / ${games.length} correct',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Updated ${_formatTime(state.lastUpdated)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (leaderboard.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _MiniLeaderboard(
                                entries: leaderboard,
                                onViewAll: () => context.pushNamed(
                                  'liveStandings',
                                  pathParameters: {'weekId': weekId},
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final game = games[index];
                        final myPick = myPicks[game.id];
                        return LiveGameCard(
                          game: game,
                          myPickedTeamId: myPick?.pickedTeamId,
                          myPickIsCorrect: myPick?.isCorrect,
                        );
                      }, childCount: games.length),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  ],
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  PickSummaryEntryModel? _findEntry(
    List<PickSummaryEntryModel> entries,
    String userId,
  ) {
    for (final entry in entries) {
      if (entry.userId == userId) return entry;
    }
    return null;
  }

  List<LiveLeaderboardEntry> _buildLeaderboard(
    List<PickSummaryEntryModel> entries,
  ) {
    return buildLiveLeaderboard(entries).take(5).toList();
  }

  static String _formatTime(DateTime dateTime) {
    final d = dateTime.toLocal();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _MiniLeaderboard extends StatelessWidget {
  const _MiniLeaderboard({required this.entries, required this.onViewAll});

  final List<LiveLeaderboardEntry> entries;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onViewAll,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Top 5', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  Text('View All', style: theme.textTheme.labelLarge),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < entries.length; i++)
                LiveLeaderboardRow(position: i + 1, entry: entries[i]),
            ],
          ),
        ),
      ),
    );
  }
}
