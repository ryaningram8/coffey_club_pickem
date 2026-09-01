import 'package:flutter/material.dart';
import '../models/game_model.dart';
import 'tiebreaker_badge.dart';

/// A single game in the pick sheet — teams, time, spread/O-U, and
/// tap-to-pick team buttons with a highlighted selected state.
class PickGameCard extends StatelessWidget {
  const PickGameCard({
    super.key,
    required this.game,
    required this.selectedTeamId,
    required this.onTeamSelected,
    this.tiebreakerGuess,
    this.onTiebreakerGuessChanged,
  });

  final GameModel game;
  final String? selectedTeamId;
  final ValueChanged<String> onTeamSelected;

  /// Only meaningful (and only rendered) when `game.isTiebreaker` is true.
  final int? tiebreakerGuess;
  final ValueChanged<int?>? onTiebreakerGuessChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = game.gameTime.toLocal();
    final timeLabel =
        '${_weekday(time.weekday)} '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
        '${game.network != null ? ' · ${game.network}' : ''}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: game.isTiebreaker
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.tertiary, width: 1.5),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (game.isTiebreaker) ...[
              const TiebreakerBadge(),
              const SizedBox(height: 6),
            ],
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
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            if (game.isNeutralSite ||
                game.venueName != null ||
                game.venueCity != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      [
                        if (game.isNeutralSite) 'Neutral Site',
                        if (game.venueName != null) game.venueName!,
                        if (game.venueCity != null) game.venueCity!,
                        if (game.venueCountry != null) game.venueCountry!,
                      ].join(' · '),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TeamButton(
                    label: game.awayTeam.name,
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
                    label: game.homeTeam.name,
                    selected: selectedTeamId == game.homeTeam.id,
                    onTap: () => onTeamSelected(game.homeTeam.id),
                  ),
                ),
              ],
            ),
            if (game.isTiebreaker) ...[
              const SizedBox(height: 8),
              _TiebreakerGuessField(
                value: tiebreakerGuess,
                onChanged: onTiebreakerGuessChanged ?? (_) {},
              ),
            ],
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

/// Numeric input for a tiebreaker's combined-final-score guess. Owns its own
/// [TextEditingController] rather than rebuilding from [value] on every
/// keystroke (which would fight the user's typing/cursor position) — it
/// only re-syncs the displayed text when [value] changes for a reason other
/// than this field's own [onChanged] echoing back, e.g. switching players
/// in the commissioner's "Enter Picks for Player" flow.
class _TiebreakerGuessField extends StatefulWidget {
  const _TiebreakerGuessField({required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  State<_TiebreakerGuessField> createState() => _TiebreakerGuessFieldState();
}

class _TiebreakerGuessFieldState extends State<_TiebreakerGuessField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value?.toString() ?? '',
  );

  @override
  void didUpdateWidget(covariant _TiebreakerGuessField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != int.tryParse(_controller.text)) {
      _controller.text = widget.value?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Your guess: combined final score',
        isDense: true,
        border: OutlineInputBorder(),
      ),
      onChanged: (text) => widget.onChanged(int.tryParse(text)),
    );
  }
}

class _TeamButton extends StatelessWidget {
  const _TeamButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

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
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outline,
          width: selected ? 2 : 1,
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
