import 'package:flutter/material.dart';
import '../models/game_model.dart';
import 'pick_correctness_icon.dart';
import 'tiebreaker_badge.dart';

/// A single game on the live results screen — live score, status, and the
/// current user's pick correctness overlay (from PickGameCard, which is
/// pick-sheet-only and has no score/status/correctness display).
class LiveGameCard extends StatelessWidget {
  const LiveGameCard({
    super.key,
    required this.game,
    required this.myPickedTeamId,
    required this.myPickIsCorrect,
  });

  final GameModel game;
  final String? myPickedTeamId;
  final bool? myPickIsCorrect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              children: [
                if (game.status == 'scheduled')
                  Text(_timeLabel(game.gameTime), style: theme.textTheme.labelMedium)
                else
                  _StatusChip(status: game.status),
                if (game.network != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    game.network!,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const Spacer(),
                if (myPickedTeamId != null)
                  PickCorrectnessIcon(isCorrect: myPickIsCorrect),
              ],
            ),
            const SizedBox(height: 8),
            _TeamScoreRow(
              label: game.awayTeam.name,
              score: game.awayScore,
              isWinner: game.winnerTeamId == game.awayTeam.id,
              isMyPick: myPickedTeamId == game.awayTeam.id,
            ),
            const SizedBox(height: 4),
            _TeamScoreRow(
              label: game.homeTeam.name,
              score: game.homeScore,
              isWinner: game.winnerTeamId == game.homeTeam.id,
              isMyPick: myPickedTeamId == game.homeTeam.id,
            ),
          ],
        ),
      ),
    );
  }
}

String _timeLabel(DateTime gameTime) {
  final time = gameTime.toLocal();
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${weekdays[time.weekday - 1]} '
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLive = status == 'in_progress';
    return Chip(
      label: Text(status.replaceAll('_', ' ')),
      backgroundColor: isLive ? theme.colorScheme.primaryContainer : null,
      labelStyle: isLive
          ? TextStyle(color: theme.colorScheme.onPrimaryContainer)
          : null,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _TeamScoreRow extends StatelessWidget {
  const _TeamScoreRow({
    required this.label,
    required this.score,
    required this.isWinner,
    required this.isMyPick,
  });

  final String label;
  final int? score;
  final bool isWinner;
  final bool isMyPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weight = isWinner ? FontWeight.bold : FontWeight.normal;
    return Row(
      children: [
        if (isMyPick)
          Icon(Icons.star, size: 16, color: theme.colorScheme.secondary)
        else
          const SizedBox(width: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: weight, fontSize: 16),
          ),
        ),
        Text(
          score?.toString() ?? '-',
          style: TextStyle(fontWeight: weight, fontSize: 16),
        ),
      ],
    );
  }
}
