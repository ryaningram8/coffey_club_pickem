import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/game_selection/game_selection_bloc.dart';
import '../../repositories/game_repository.dart';
import '../../repositories/week_repository.dart';
import '../../widgets/available_game_tile.dart';

/// Commissioner game browser + selection + publish flow, all in one screen:
/// search available games, toggle a selection with a running college/NFL
/// count, then confirm-publish to assign them to the week.
class GameBrowserScreen extends StatelessWidget {
  const GameBrowserScreen({super.key, required this.weekId});

  final String weekId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => GameSelectionBloc(
        gameRepository: context.read<GameRepository>(),
        weekRepository: context.read<WeekRepository>(),
        weekId: weekId,
      )..add(const GameSelectionEvent.started()),
      child: const _GameBrowserView(),
    );
  }
}

class _GameBrowserView extends StatefulWidget {
  const _GameBrowserView();

  @override
  State<_GameBrowserView> createState() => _GameBrowserViewState();
}

class _GameBrowserViewState extends State<_GameBrowserView> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Games')),
      body: BlocConsumer<GameSelectionBloc, GameSelectionState>(
        listener: (context, state) {
          if (state is GameSelectionPublished) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Week published')));
            Navigator.of(context).pop();
          }
          if (state is GameSelectionFailure) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        builder: (context, state) {
          if (state is GameSelectionInitial || state is GameSelectionLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is GameSelectionFailure) {
            return const Center(child: Text('Could not load available games.'));
          }
          if (state is GameSelectionLoaded) {
            final filtered = state.available.where((g) {
              if (_query.isEmpty) return true;
              final q = _query.toLowerCase();
              return g.homeTeam.name.toLowerCase().contains(q) ||
                  g.awayTeam.name.toLowerCase().contains(q);
            }).toList();

            final collegeCount = state.selected.where((g) => g.sport == 'college').length;
            final nflCount = state.selected.where((g) => g.sport == 'nfl').length;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search teams',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Selected: $collegeCount / 14 college · $nflCount / 6 NFL',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No games match your search.'))
                      : CustomScrollView(
                          slivers: [
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final game = filtered[index];
                                  final isSelected = state.selected
                                      .any((g) => g.espnGameId == game.espnGameId);
                                  return AvailableGameTile(
                                    game: game,
                                    selected: isSelected,
                                    onChanged: (_) => context
                                        .read<GameSelectionBloc>()
                                        .add(GameSelectionEvent.gameToggled(game)),
                                  );
                                },
                                childCount: filtered.length,
                              ),
                            ),
                          ],
                        ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: FilledButton(
                      onPressed: state.selected.isEmpty || state.isPublishing
                          ? null
                          : () => _confirmPublish(context, state.selected.length),
                      child: state.isPublishing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text('Publish ${state.selected.length} Games'),
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

  void _confirmPublish(BuildContext context, int count) {
    final bloc = context.read<GameSelectionBloc>();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Publish Week?'),
        content: Text(
          'This will assign $count games to the week and open picks for players. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              bloc.add(const GameSelectionEvent.publishRequested());
            },
            child: const Text('Publish'),
          ),
        ],
      ),
    );
  }
}
