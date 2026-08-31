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
    final hasStarted = game.gameTime.isBefore(DateTime.now());

    return CheckboxListTile(
      value: selected,
      onChanged: hasStarted ? null : onChanged,
      enabled: !hasStarted,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text('${game.awayTeam.name} @ ${game.homeTeam.name}'),
      subtitle: Text(
        [
          _sportLabel(game.sport),
          hasStarted ? 'Started' : dateLabel,
          if (game.spread != null) 'Spread ${game.spread}',
          if (game.overUnder != null) 'O/U ${game.overUnder}',
          if (game.isNeutralSite) 'Neutral Site',
          if (game.venueName != null) game.venueName!,
          if (game.venueCity != null) game.venueCity!,
          if (game.venueCountry != null) game.venueCountry!,
        ].join(' · '),
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}

String _sportLabel(String sport) {
  switch (sport) {
    case 'college':
      return 'College';
    case 'nfl':
      return 'NFL';
    case 'mlb':
      return 'MLB';
    default:
      return sport;
  }
}
