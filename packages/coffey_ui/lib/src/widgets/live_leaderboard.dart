import 'package:flutter/material.dart';
import '../models/pick_summary_model.dart';

class LiveLeaderboardEntry {
  LiveLeaderboardEntry({
    required this.userId,
    required this.userName,
    required this.correct,
    required this.total,
  });

  final String userId;
  final String userName;
  final int correct;
  final int total;
}

List<LiveLeaderboardEntry> buildLiveLeaderboard(
  List<PickSummaryEntryModel> entries,
) {
  return entries
      .map(
        (e) => LiveLeaderboardEntry(
          userId: e.userId,
          userName: e.userName,
          correct: e.picks.where((p) => p.isCorrect == true).length,
          total: e.picks.length,
        ),
      )
      .toList()
    ..sort((a, b) => b.correct.compareTo(a.correct));
}

class LiveLeaderboardRow extends StatelessWidget {
  const LiveLeaderboardRow({
    super.key,
    required this.position,
    required this.entry,
  });

  final int position;
  final LiveLeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 28, child: Text('$position.')),
          Expanded(child: Text(entry.userName)),
          Text('${entry.correct} / ${entry.total}'),
        ],
      ),
    );
  }
}
