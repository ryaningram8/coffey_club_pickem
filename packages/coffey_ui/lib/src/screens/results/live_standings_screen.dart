import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/live_results/live_results_bloc.dart';
import '../../models/week_tiebreaker_model.dart';
import '../../repositories/standings_repository.dart';
import '../../repositories/week_repository.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/error_state_view.dart';
import '../../widgets/live_leaderboard.dart';
import '../../widgets/responsive_content.dart';
import '../../widgets/skeleton_loaders.dart';
import '../../widgets/tiebreaker_group_breakdown.dart';

class LiveStandingsScreen extends StatelessWidget {
  const LiveStandingsScreen({super.key, required this.weekId});

  final String weekId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LiveResultsBloc(
        weekRepository: context.read<WeekRepository>(),
        standingsRepository: context.read<StandingsRepository>(),
        weekId: weekId,
      )..add(const LiveResultsEvent.started()),
      child: const _LiveStandingsView(),
    );
  }
}

class _LiveStandingsView extends StatelessWidget {
  const _LiveStandingsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Standings')),
      body: BlocBuilder<LiveResultsBloc, LiveResultsState>(
        builder: (context, state) {
          if (state is LiveResultsInitial || state is LiveResultsLoading) {
            return const SkeletonLeaderboardList();
          }
          if (state is LiveResultsFailure) {
            return ErrorStateView(
              message: 'Could not load live standings: ${state.message}',
              onRetry: () => context.read<LiveResultsBloc>().add(
                const LiveResultsEvent.started(),
              ),
            );
          }
          if (state is LiveResultsLoaded) {
            final leaderboard = buildLiveLeaderboard(state.picksSummary);
            if (leaderboard.isEmpty) {
              return const EmptyStateView(
                icon: Icons.leaderboard_outlined,
                message: 'No picks submitted for this week yet.',
              );
            }
            final rows = _buildRows(leaderboard, state.tiebreaker);
            return RefreshIndicator(
              onRefresh: () async => context.read<LiveResultsBloc>().add(
                const LiveResultsEvent.refreshed(),
              ),
              child: ResponsiveContent(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: rows,
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  /// Leaderboard rows with a [TiebreakerGroupBreakdown] inserted right after
  /// any cluster of consecutive entries tied on `correct` count — this list
  /// has no per-row expand state (unlike weekly standings), so ties are
  /// shown inline rather than behind a tap.
  List<Widget> _buildRows(
    List<LiveLeaderboardEntry> leaderboard,
    WeekTiebreakerModel tiebreaker,
  ) {
    final rows = <Widget>[];
    var i = 0;
    while (i < leaderboard.length) {
      var j = i + 1;
      while (j < leaderboard.length &&
          leaderboard[j].correct == leaderboard[i].correct) {
        j++;
      }
      for (var k = i; k < j; k++) {
        if (rows.isNotEmpty) rows.add(const Divider());
        rows.add(LiveLeaderboardRow(position: k + 1, entry: leaderboard[k]));
      }
      if (j - i > 1 && tiebreaker.games.isNotEmpty) {
        rows.add(
          TiebreakerGroupBreakdown(
            tiebreaker: tiebreaker,
            tiedUserIds: leaderboard
                .sublist(i, j)
                .map((e) => e.userId)
                .toSet(),
          ),
        );
      }
      i = j;
    }
    return rows;
  }
}
