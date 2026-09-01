import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/enter_picks/enter_picks_bloc.dart';
import '../../repositories/pick_repository.dart';
import '../../repositories/season_repository.dart';
import '../../repositories/week_repository.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/error_state_view.dart';
import '../../widgets/pick_game_card.dart';
import '../../widgets/responsive_content.dart';
import '../../widgets/skeleton_loaders.dart';

/// Commissioner-only: enter/correct a player's picks on their behalf (paper
/// pick sheet catch-up). Unlike the self-pick screen, there's no pick
/// deadline gating and submission doesn't require every game to be picked.
class EnterPicksScreen extends StatelessWidget {
  const EnterPicksScreen({super.key, required this.weekId});

  final String weekId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => EnterPicksBloc(
        weekRepository: context.read<WeekRepository>(),
        pickRepository: context.read<PickRepository>(),
        seasonRepository: context.read<SeasonRepository>(),
        weekId: weekId,
      )..add(const EnterPicksEvent.started()),
      child: const _EnterPicksView(),
    );
  }
}

class _EnterPicksView extends StatefulWidget {
  const _EnterPicksView();

  @override
  State<_EnterPicksView> createState() => _EnterPicksViewState();
}

class _EnterPicksViewState extends State<_EnterPicksView> {
  static const _createPlayerValue = '__create_player__';

  // Selecting "Create Player" isn't a real player selection, so it must
  // never reach the bloc as one — reset() reverts the dropdown's own
  // display back to the bloc's selectedPlayerId before opening the dialog.
  final _dropdownKey = GlobalKey<FormFieldState<String>>();

  void _showCreatePlayerDialog(BuildContext context, String seasonId) {
    final bloc = context.read<EnterPicksBloc>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create Player'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final email = emailController.text.trim();
                if (name.isEmpty || email.isEmpty) return;
                bloc.add(EnterPicksEvent.playerCreated(name: name, email: email));
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter Picks for Player')),
      body: BlocConsumer<EnterPicksBloc, EnterPicksState>(
        listener: (context, state) {
          if (state is EnterPicksLoaded) {
            if (state.justSubmitted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Picks saved!')));
            }
            if (state.errorMessage != null) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
            }
          }
        },
        builder: (context, state) {
          if (state is EnterPicksInitial || state is EnterPicksLoading) {
            return const SkeletonGameCardList();
          }
          if (state is EnterPicksFailure) {
            return ErrorStateView(
              message: 'Could not load this week.',
              onRetry: () => context.read<EnterPicksBloc>().add(
                const EnterPicksEvent.started(),
              ),
            );
          }
          if (state is EnterPicksLoaded) {
            final games = state.week.games;
            final pickedCount = state.selections.length;
            final canSubmit =
                state.selectedPlayerId != null &&
                state.selections.isNotEmpty &&
                !state.isSubmitting;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: DropdownButtonFormField<String>(
                    key: _dropdownKey,
                    initialValue: state.selectedPlayerId,
                    decoration: const InputDecoration(
                      labelText: 'Player',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final member in state.roster)
                        DropdownMenuItem(
                          value: member.userId,
                          child: Text('${member.name} (${member.email})'),
                        ),
                      const DropdownMenuItem(
                        value: _createPlayerValue,
                        child: Text('+ Create Player'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      if (value == _createPlayerValue) {
                        _dropdownKey.currentState?.reset();
                        _showCreatePlayerDialog(context, state.week.seasonId);
                        return;
                      }
                      context.read<EnterPicksBloc>().add(
                        EnterPicksEvent.playerSelected(value),
                      );
                    },
                  ),
                ),
                if (state.selectedPlayerId != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('$pickedCount / ${games.length} picks made'),
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: state.selectedPlayerId == null
                      ? const EmptyStateView(
                          icon: Icons.person_search_outlined,
                          message: 'Select a player above to enter their picks.',
                        )
                      : games.isEmpty
                      ? const EmptyStateView(
                          icon: Icons.sports_football_outlined,
                          message: 'No games assigned for this week yet.',
                        )
                      : ResponsiveContent(
                          child: CustomScrollView(
                            slivers: [
                              SliverList(
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  index,
                                ) {
                                  final game = games[index];
                                  return PickGameCard(
                                    game: game,
                                    selectedTeamId: state.selections[game.id],
                                    onTeamSelected: (teamId) => context
                                        .read<EnterPicksBloc>()
                                        .add(
                                          EnterPicksEvent.teamSelected(
                                            gameId: game.id,
                                            teamId: teamId,
                                          ),
                                        ),
                                    tiebreakerGuess:
                                        state.tiebreakerGuesses[game.id],
                                    onTiebreakerGuessChanged: (guess) =>
                                        context.read<EnterPicksBloc>().add(
                                          EnterPicksEvent.tiebreakerGuessChanged(
                                            gameId: game.id,
                                            guess: guess,
                                          ),
                                        ),
                                  );
                                }, childCount: games.length),
                              ),
                              const SliverToBoxAdapter(child: SizedBox(height: 16)),
                            ],
                          ),
                        ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: FilledButton(
                      onPressed: canSubmit
                          ? () => context.read<EnterPicksBloc>().add(
                              const EnterPicksEvent.submitRequested(),
                            )
                          : null,
                      child: state.isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Picks'),
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
