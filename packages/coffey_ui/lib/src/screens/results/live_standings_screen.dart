import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/live_results/live_results_bloc.dart';
import '../../repositories/standings_repository.dart';
import '../../repositories/week_repository.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/error_state_view.dart';
import '../../widgets/live_leaderboard.dart';
import '../../widgets/responsive_content.dart';
import '../../widgets/skeleton_loaders.dart';

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
            return RefreshIndicator(
              onRefresh: () async => context.read<LiveResultsBloc>().add(
                const LiveResultsEvent.refreshed(),
              ),
              child: ResponsiveContent(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: leaderboard.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) => LiveLeaderboardRow(
                    position: index + 1,
                    entry: leaderboard[index],
                  ),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
