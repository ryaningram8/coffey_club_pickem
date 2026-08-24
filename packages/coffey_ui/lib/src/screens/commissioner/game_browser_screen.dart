import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/game_selection/game_selection_bloc.dart';
import '../../repositories/game_repository.dart';
import '../../repositories/week_repository.dart';
import '../../widgets/available_game_tile.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/error_state_view.dart';
import '../../widgets/responsive_content.dart';

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
  String? _sportFilter;

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
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Week published')));
            Navigator.of(context).pop();
          }
          if (state is GameSelectionFailure) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        builder: (context, state) {
          if (state is GameSelectionInitial || state is GameSelectionLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is GameSelectionFailure) {
            return ErrorStateView(
              message: 'Could not load available games.',
              onRetry: () => context.read<GameSelectionBloc>().add(
                const GameSelectionEvent.started(),
              ),
            );
          }
          if (state is GameSelectionLoaded) {
            final filtered = state.available.where((g) {
              if (_sportFilter != null && g.sport != _sportFilter) return false;
              if (_query.isEmpty) return true;
              final q = _query.toLowerCase();
              return g.homeTeam.name.toLowerCase().contains(q) ||
                  g.awayTeam.name.toLowerCase().contains(q);
            }).toList();

            final selectedCounts = <String, int>{};
            for (final g in state.selected) {
              selectedCounts[g.sport] = (selectedCounts[g.sport] ?? 0) + 1;
            }
            final countLabel = selectedCounts.entries
                .map((e) => _sportCountLabel(e.key, e.value))
                .join(' · ');

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
                  child: Wrap(
                    spacing: 8,
                    children: [
                      _SportFilterChip(
                        label: 'All',
                        selected: _sportFilter == null,
                        onSelected: () => setState(() => _sportFilter = null),
                      ),
                      _SportFilterChip(
                        label: 'College',
                        selected: _sportFilter == 'college',
                        onSelected: () =>
                            setState(() => _sportFilter = 'college'),
                      ),
                      _SportFilterChip(
                        label: 'NFL',
                        selected: _sportFilter == 'nfl',
                        onSelected: () => setState(() => _sportFilter = 'nfl'),
                      ),
                      _SportFilterChip(
                        label: 'MLB',
                        selected: _sportFilter == 'mlb',
                        onSelected: () => setState(() => _sportFilter = 'mlb'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text('From ${_formatDate(state.startDate)}'),
                          onPressed: state.isRefetching
                              ? null
                              : () => _pickStartDate(context, state),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text('To ${_formatDate(state.endDate)}'),
                          onPressed: state.isRefetching
                              ? null
                              : () => _pickEndDate(context, state),
                        ),
                      ),
                    ],
                  ),
                ),
                if (state.isRefetching) const LinearProgressIndicator(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      countLabel.isEmpty ? 'Selected: none yet' : 'Selected: $countLabel',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? EmptyStateView(
                          icon: Icons.sports_football_outlined,
                          message: state.available.isEmpty
                              ? 'No games available from ESPN yet for this window.'
                              : 'No games match your search.',
                        )
                      : ResponsiveContent(
                          child: CustomScrollView(
                            slivers: [
                              SliverList(
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  index,
                                ) {
                                  final game = filtered[index];
                                  final isSelected = state.selected.any(
                                    (g) => g.espnGameId == game.espnGameId,
                                  );
                                  return AvailableGameTile(
                                    game: game,
                                    selected: isSelected,
                                    onChanged: (_) =>
                                        context.read<GameSelectionBloc>().add(
                                          GameSelectionEvent.gameToggled(game),
                                        ),
                                  );
                                }, childCount: filtered.length),
                              ),
                            ],
                          ),
                        ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: FilledButton(
                      onPressed: state.selected.isEmpty || state.isPublishing
                          ? null
                          : () =>
                                _confirmPublish(context, state.selected.length),
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

  static String _formatDate(DateTime d) => '${d.month}/${d.day}';

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _pickStartDate(BuildContext context, GameSelectionLoaded state) async {
    final today = _today();
    final picked = await showDatePicker(
      context: context,
      initialDate: state.startDate.isBefore(today) ? today : state.startDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 180)),
    );
    if (picked == null || !context.mounted) return;
    final endDate = picked.isAfter(state.endDate)
        ? picked.add(const Duration(days: 1))
        : state.endDate;
    context.read<GameSelectionBloc>().add(
      GameSelectionEvent.dateRangeChanged(startDate: picked, endDate: endDate),
    );
  }

  Future<void> _pickEndDate(BuildContext context, GameSelectionLoaded state) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: state.endDate,
      firstDate: state.startDate,
      lastDate: state.startDate.add(const Duration(days: 180)),
    );
    if (picked == null || !context.mounted) return;
    context.read<GameSelectionBloc>().add(
      GameSelectionEvent.dateRangeChanged(startDate: state.startDate, endDate: picked),
    );
  }

  static const _sportTargets = {'college': 14, 'nfl': 6};

  String _sportCountLabel(String sport, int count) {
    final label = switch (sport) {
      'college' => 'college',
      'nfl' => 'NFL',
      'mlb' => 'MLB',
      _ => sport,
    };
    final target = _sportTargets[sport];
    return target != null ? '$count / $target $label' : '$count $label';
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

class _SportFilterChip extends StatelessWidget {
  const _SportFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}
