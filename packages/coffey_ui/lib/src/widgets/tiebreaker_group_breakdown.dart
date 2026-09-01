import 'package:flutter/material.dart';
import '../models/week_tiebreaker_model.dart';

/// Lines up every player tied within one group so it's easy to see at a
/// glance who's closest (e.g. when 5 people are tied for 2nd, who actually
/// wins the payout tiebreak) — shared by the weekly standings screen (one
/// tied rank, expanded on tap) and the live standings screen (every tied
/// cluster shown inline, since that list has no per-row expand state).
class TiebreakerGroupBreakdown extends StatelessWidget {
  const TiebreakerGroupBreakdown({
    super.key,
    required this.tiebreaker,
    required this.tiedUserIds,
    this.highlightUserId,
  });

  final WeekTiebreakerModel tiebreaker;
  final Set<String> tiedUserIds;

  /// Bolds/highlights one entry — e.g. the row the user tapped to expand.
  /// Leave null to show every tied entry the same way.
  final String? highlightUserId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = tiebreaker.entries
        .where((e) => tiedUserIds.contains(e.userId))
        .toList()
      ..sort((a, b) {
        final da = a.distance;
        final db = b.distance;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });

    if (entries.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          Text('Tiebreaker', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          for (final game in tiebreaker.games)
            Text(
              '${game.awayTeamName} @ ${game.homeTeamName}: '
              '${game.actualCombinedScore?.toString() ?? 'pending'} combined',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 6),
          for (final entry in entries) _buildEntryRow(context, entry),
        ],
      ),
    );
  }

  Widget _buildEntryRow(BuildContext context, TiebreakerEntryModel entry) {
    final theme = Theme.of(context);
    final isHighlighted = entry.userId == highlightUserId;
    final guessByGameId = {for (final g in entry.guesses) g.gameId: g.guess};
    final guessText = tiebreaker.games
        .map((g) => guessByGameId[g.gameId]?.toString() ?? '—')
        .join(' + ');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      decoration: isHighlighted
          ? BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(
                alpha: 0.4,
              ),
              borderRadius: BorderRadius.circular(6),
            )
          : null,
      child: Row(
        children: [
          Expanded(
            child: Text(
              entry.userName,
              style: isHighlighted
                  ? const TextStyle(fontWeight: FontWeight.bold)
                  : null,
            ),
          ),
          Text(
            'Guessed $guessText'
            '${entry.guessTotal != null ? ' = ${entry.guessTotal}' : ''}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(width: 8),
          Text(
            entry.distance != null ? 'off by ${entry.distance}' : 'pending',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
