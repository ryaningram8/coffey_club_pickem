import 'package:flutter/material.dart';
import '../models/game_model.dart';

/// A single game in the pick sheet — teams, time, spread/O-U, and
/// tap-to-pick team buttons with a highlighted selected state.
class PickGameCard extends StatelessWidget {
  const PickGameCard({
    super.key,
    required this.game,
    required this.selectedTeamId,
    required this.onTeamSelected,
  });

  final GameModel game;
  final String? selectedTeamId;
  final ValueChanged<String> onTeamSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = game.gameTime.toLocal();
    final timeLabel = '${_weekday(time.weekday)} '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(timeLabel, style: theme.textTheme.labelMedium),
                if (game.spread != null || game.overUnder != null)
                  Text(
                    [
                      if (game.spread != null) 'Spread ${game.spread}',
                      if (game.overUnder != null) 'O/U ${game.overUnder}',
                    ].join(' · '),
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TeamButton(
                    label: game.awayTeam.abbreviation,
                    selected: selectedTeamId == game.awayTeam.id,
                    onTap: () => onTeamSelected(game.awayTeam.id),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('@'),
                ),
                Expanded(
                  child: _TeamButton(
                    label: game.homeTeam.abbreviation,
                    selected: selectedTeamId == game.homeTeam.id,
                    onTap: () => onTeamSelected(game.homeTeam.id),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _weekday(int weekday) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[weekday - 1];
  }
}

class _TeamButton extends StatelessWidget {
  const _TeamButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? theme.colorScheme.primaryContainer : null,
        foregroundColor: selected ? theme.colorScheme.onPrimaryContainer : null,
        side: BorderSide(
          color: selected ? theme.colorScheme.primary : theme.colorScheme.outline,
          width: selected ? 2 : 1,
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
