import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../blocs/home_hero/home_hero_cubit.dart';
import '../models/week_model.dart';
import '../models/week_standing_model.dart';
import '../models/week_summary_model.dart';

/// The home screen's adaptive "what's going on" card — this week's pick
/// status, last week's recap, or a live-games snapshot, depending on
/// [HomeHeroCubit]'s classification. Renders nothing for the states that
/// shouldn't interrupt the plain button list (initial/loading covers itself
/// with a spinner; empty/failure render nothing so the rest of the home
/// screen stays usable).
class HomeHeroCard extends StatelessWidget {
  const HomeHeroCard({super.key, required this.state});

  final HomeHeroState state;

  @override
  Widget build(BuildContext context) {
    final primary = state.when(
      initial: () => const SizedBox.shrink(),
      loading: () => const _HeroCardShell(
        child: Center(child: CircularProgressIndicator()),
      ),
      thisWeek: (week, picksMade, totalGames, lastWeekLabel, lastWeekMessage) =>
          _ThisWeekCard(week: week, picksMade: picksMade, totalGames: totalGames),
      lastWeekRecap: (week, myStanding) =>
          _LastWeekRecapCard(week: week, myStanding: myStanding),
      live: (week, myCorrect, gamesFinal, gamesInProgress, totalGames, lastWeekLabel,
              lastWeekMessage) =>
          _LiveWeekCard(
        week: week,
        myCorrect: myCorrect,
        gamesFinal: gamesFinal,
        gamesInProgress: gamesInProgress,
        totalGames: totalGames,
      ),
      empty: () => const SizedBox.shrink(),
      failure: (message) => const SizedBox.shrink(),
    );

    // The commissioner's roast is about LAST week — when the recap card is
    // already showing that week, it's shown inline there instead of
    // repeated in a separate banner.
    final banner = state.maybeWhen(
      thisWeek: (week, picksMade, totalGames, lastWeekLabel, lastWeekMessage) =>
          lastWeekMessage != null
              ? _CommissionerMessageBanner(label: lastWeekLabel!, message: lastWeekMessage)
              : null,
      live: (week, myCorrect, gamesFinal, gamesInProgress, totalGames, lastWeekLabel,
              lastWeekMessage) =>
          lastWeekMessage != null
              ? _CommissionerMessageBanner(label: lastWeekLabel!, message: lastWeekMessage)
              : null,
      orElse: () => null,
    );

    if (banner == null) return primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [primary, const SizedBox(height: 12), banner],
    );
  }
}

class _HeroCardShell extends StatelessWidget {
  const _HeroCardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(height: 96, child: child),
      ),
    );
  }
}

class _ThisWeekCard extends StatelessWidget {
  const _ThisWeekCard({required this.week, required this.picksMade, required this.totalGames});

  final WeekModel week;
  final int? picksMade;
  final int totalGames;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deadlineLabel = _formatDeadline(week.pickDeadline);
    final hasPicks = picksMade != null && totalGames > 0;
    final allPicked = hasPicks && picksMade! >= totalGames;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(week.label, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              hasPicks ? 'Picks close $deadlineLabel' : 'Picks open soon · closes $deadlineLabel',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (week.pot != null) ...[
              const SizedBox(height: 4),
              Text(
                'This week\'s pot: \$${week.pot}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            if (hasPicks) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: picksMade! / totalGames),
              ),
              const SizedBox(height: 4),
              Text('$picksMade / $totalGames picks made', style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () =>
                  context.pushNamed('pickSheet', pathParameters: {'weekId': week.id}),
              icon: const Icon(Icons.checklist),
              label: Text(!hasPicks
                  ? 'View Games'
                  : allPicked
                      ? 'Picks Submitted'
                      : picksMade! > 0
                          ? 'Edit Your Picks'
                          : 'Make Your Picks'),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDeadline(DateTime pickDeadline) {
    final d = pickDeadline.toLocal();
    final dateLabel = '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
    final remaining = pickDeadline.difference(DateTime.now());
    if (remaining.isNegative) return dateLabel;
    if (remaining.inDays >= 1) return '$dateLabel (${remaining.inDays}d left)';
    if (remaining.inHours >= 1) return '$dateLabel (${remaining.inHours}h left)';
    return '$dateLabel (${remaining.inMinutes}m left)';
  }
}

class _LastWeekRecapCard extends StatelessWidget {
  const _LastWeekRecapCard({required this.week, required this.myStanding});

  final WeekSummaryModel week;
  final WeekStandingModel? myStanding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final standing = myStanding;
    final wrongPicks =
        standing != null ? standing.totalPicks - standing.correctPicks : null;
    final payout = double.tryParse(standing?.payoutAmount ?? '');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Last Week: ${week.label}', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (standing != null) ...[
              Text(
                'You went ${standing.correctPicks}-$wrongPicks'
                '${standing.rank != null ? ', finished #${standing.rank}' : ''}',
                style: theme.textTheme.bodyMedium,
              ),
              if (payout != null && payout > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'Won \$${payout.toStringAsFixed(2)}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                ),
              ],
            ] else
              Text(
                'Standings are up for ${week.label}.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            if (week.commissionerMessage?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                '"${week.commissionerMessage}"',
                style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () =>
                  context.pushNamed('weeklyStandings', pathParameters: {'weekId': week.id}),
              icon: const Icon(Icons.leaderboard_outlined),
              label: const Text('View Full Standings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveWeekCard extends StatelessWidget {
  const _LiveWeekCard({
    required this.week,
    required this.myCorrect,
    required this.gamesFinal,
    required this.gamesInProgress,
    required this.totalGames,
  });

  final WeekModel week;
  final int myCorrect;
  final int gamesFinal;
  final int gamesInProgress;
  final int totalGames;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${week.label} — Live',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 4),
            Text(
              '$gamesFinal of $totalGames games final'
              '${gamesInProgress > 0 ? ' · $gamesInProgress in progress' : ''}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 4),
            Text(
              'You\'re $myCorrect correct so far',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () =>
                  context.pushNamed('liveResults', pathParameters: {'weekId': week.id}),
              icon: const Icon(Icons.live_tv_outlined),
              label: const Text('Watch Live'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The commissioner's weekly roast — shown alongside the This Week / Live
/// cards so it stays visible through the whole week that follows, not just
/// the brief gap the Last Week Recap card occupies.
class _CommissionerMessageBanner extends StatelessWidget {
  const _CommissionerMessageBanner({required this.label, required this.message});

  final String label;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.campaign_outlined, color: theme.colorScheme.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'From the commissioner — $label',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Text('"$message"', style: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
