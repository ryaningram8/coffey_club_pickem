import 'package:flutter/material.dart';
import '../models/game_model.dart';
import 'pick_correctness_icon.dart';

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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _StatusChip(status: game.status),
                const Spacer(),
                if (myPickedTeamId != null)
                  PickCorrectnessIcon(isCorrect: myPickIsCorrect),
              ],
            ),
            const SizedBox(height: 8),
            _TeamScoreRow(
              label: game.awayTeam.abbreviation,
              score: game.awayScore,
              isWinner: game.winnerTeamId == game.awayTeam.id,
              isMyPick: myPickedTeamId == game.awayTeam.id,
            ),
            const SizedBox(height: 4),
            _TeamScoreRow(
              label: game.homeTeam.abbreviation,
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
