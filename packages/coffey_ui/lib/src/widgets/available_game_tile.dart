import 'package:flutter/material.dart';
import '../models/available_game_model.dart';

/// Commissioner-side row for a candidate game from `GET /games/available`.
class AvailableGameTile extends StatelessWidget {
  const AvailableGameTile({
    super.key,
    required this.game,
    required this.selected,
    required this.onChanged,
  });

  final AvailableGameModel game;
  final bool selected;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = game.gameTime.toLocal();
    final dateLabel =
        '${time.month}/${time.day} '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return CheckboxListTile(
      value: selected,
      onChanged: onChanged,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text('${game.awayTeam.name} @ ${game.homeTeam.name}'),
      subtitle: Text(
        [
          game.sport == 'college' ? 'College' : 'NFL',
          dateLabel,
          if (game.spread != null) 'Spread ${game.spread}',
          if (game.overUnder != null) 'O/U ${game.overUnder}',
        ].join(' · '),
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}
