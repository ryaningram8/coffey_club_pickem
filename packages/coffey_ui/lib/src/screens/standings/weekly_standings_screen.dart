import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/weekly_standings/weekly_standings_bloc.dart';
import '../../models/game_model.dart';
import '../../models/pick_summary_model.dart';
import '../../repositories/standings_repository.dart';
import '../../repositories/week_repository.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/error_state_view.dart';
import '../../widgets/pick_correctness_icon.dart';
import '../../widgets/responsive_content.dart';
import '../../widgets/skeleton_loaders.dart';

class WeeklyStandingsScreen extends StatelessWidget {
  const WeeklyStandingsScreen({super.key, required this.weekId});

  final String weekId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => WeeklyStandingsBloc(
        weekRepository: context.read<WeekRepository>(),
        standingsRepository: context.read<StandingsRepository>(),
        weekId: weekId,
      )..add(const WeeklyStandingsEvent.started()),
      child: const _WeeklyStandingsView(),
    );
  }
}

class _WeeklyStandingsView extends StatelessWidget {
  const _WeeklyStandingsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Standings')),
      body: BlocBuilder<WeeklyStandingsBloc, WeeklyStandingsState>(
        builder: (context, state) {
          if (state is WeeklyStandingsInitial ||
              state is WeeklyStandingsLoading) {
            return const SkeletonLeaderboardList();
          }
          if (state is WeeklyStandingsFailure) {
            return ErrorStateView(
              message: 'Could not load standings: ${state.message}',
              onRetry: () => context.read<WeeklyStandingsBloc>().add(
                const WeeklyStandingsEvent.started(),
              ),
            );
          }
          if (state is WeeklyStandingsLoaded) {
            if (state.standings.isEmpty) {
              return const EmptyStateView(
                icon: Icons.leaderboard_outlined,
                message:
                    "Results aren't final yet — check Live Results while games "
                    'are in progress.',
              );
            }
            final gamesById = {for (final g in state.week.games) g.id: g};
            final rankCounts = <int, int>{};
            for (final s in state.standings) {
              if (s.rank != null)
                rankCounts[s.rank!] = (rankCounts[s.rank!] ?? 0) + 1;
            }

            return ResponsiveContent(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: state.standings.length,
                itemBuilder: (context, index) {
                  final standing = state.standings[index];
                  final isTied =
                      standing.rank != null &&
                      (rankCounts[standing.rank!] ?? 0) > 1;
                  final isExpanded = state.expandedUserId == standing.userId;
                  final picks = _picksFor(state.picksSummary, standing.userId);

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: _RankBadge(rank: standing.rank),
                          title: Text(standing.userName),
                          subtitle: Text(
                            '${standing.correctPicks} / ${standing.totalPicks} correct'
                            '${isTied ? ' · tied' : ''}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (standing.payoutAmount != null)
                                Text(
                                  '\$${double.parse(standing.payoutAmount!).toStringAsFixed(2)}',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              Icon(
                                isExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                              ),
                            ],
                          ),
                          onTap: () => context.read<WeeklyStandingsBloc>().add(
                            WeeklyStandingsEvent.playerToggled(standing.userId),
                          ),
                        ),
                        if (isExpanded)
                          _PickBreakdown(picks: picks, gamesById: gamesById),
                      ],
                    ),
                  );
                },
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  List<PickSummaryItemModel> _picksFor(
    List<PickSummaryEntryModel> entries,
    String userId,
  ) {
    for (final entry in entries) {
      if (entry.userId == userId) return entry.picks;
    }
    return const [];
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CircleAvatar(
      backgroundColor: theme.colorScheme.secondaryContainer,
      foregroundColor: theme.colorScheme.onSecondaryContainer,
      child: Text(rank?.toString() ?? '-'),
    );
  }
}

class _PickBreakdown extends StatelessWidget {
  const _PickBreakdown({required this.picks, required this.gamesById});

  final List<PickSummaryItemModel> picks;
  final Map<String, GameModel> gamesById;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          for (final pick in picks) _buildRow(context, pick),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, PickSummaryItemModel pick) {
    final game = gamesById[pick.gameId];
    final pickedAbbreviation = game == null
        ? '?'
        : (pick.pickedTeamId == game.homeTeam.id
              ? game.homeTeam.abbreviation
              : game.awayTeam.abbreviation);
    final matchup = game == null
        ? 'Unknown game'
        : '${game.awayTeam.abbreviation} @ ${game.homeTeam.abbreviation}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          PickCorrectnessIcon(isCorrect: pick.isCorrect, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(matchup)),
          Text(
            'Picked $pickedAbbreviation',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
