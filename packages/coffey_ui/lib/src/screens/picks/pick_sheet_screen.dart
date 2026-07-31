import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/picks/picks_bloc.dart';
import '../../repositories/pick_repository.dart';
import '../../repositories/week_repository.dart';
import '../../widgets/pick_game_card.dart';

class PickSheetScreen extends StatelessWidget {
  const PickSheetScreen({super.key, required this.weekId});

  final String weekId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PicksBloc(
        weekRepository: context.read<WeekRepository>(),
        pickRepository: context.read<PickRepository>(),
        weekId: weekId,
      )..add(const PicksEvent.started()),
      child: const _PickSheetView(),
    );
  }
}

class _PickSheetView extends StatelessWidget {
  const _PickSheetView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pick Sheet')),
      body: BlocConsumer<PicksBloc, PicksState>(
        listener: (context, state) {
          if (state is PicksLoaded) {
            if (state.justSubmitted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Picks submitted!')));
            }
            if (state.errorMessage != null) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(state.errorMessage!)));
            }
          }
          if (state is PicksFailure) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        builder: (context, state) {
          if (state is PicksInitial || state is PicksLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is PicksFailure) {
            return const Center(child: Text('Could not load this week.'));
          }
          if (state is PicksLoaded) {
            final games = state.week.games;
            final pickedCount = state.selections.length;
            final isComplete = games.isNotEmpty && pickedCount == games.length;
            final deadlinePassed = state.week.pickDeadline.isBefore(DateTime.now());

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: LinearProgressIndicator(
                    value: games.isEmpty ? 0 : pickedCount / games.length,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('$pickedCount / ${games.length} picks made'),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final game = games[index];
                            return PickGameCard(
                              game: game,
                              selectedTeamId: state.selections[game.id],
                              onTeamSelected: deadlinePassed
                                  ? (_) {}
                                  : (teamId) => context.read<PicksBloc>().add(
                                        PicksEvent.teamSelected(
                                          gameId: game.id,
                                          teamId: teamId,
                                        ),
                                      ),
                            );
                          },
                          childCount: games.length,
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    ],
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: FilledButton(
                      onPressed: (!isComplete || state.isSubmitting || deadlinePassed)
                          ? null
                          : () => context.read<PicksBloc>().add(const PicksEvent.submitRequested()),
                      child: state.isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(deadlinePassed ? 'Deadline Passed' : 'Submit Picks'),
                    ),
                  ),
                ),
              ],
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
