import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../models/week_model.dart';
import '../../repositories/week_repository.dart';

/// Read-only detail view of a single week's published games — a simple
/// fetch-and-display screen, so it uses a plain FutureBuilder rather than a
/// dedicated BLoC.
class CommissionerWeekScreen extends StatefulWidget {
  const CommissionerWeekScreen({super.key, required this.weekId});

  final String weekId;

  @override
  State<CommissionerWeekScreen> createState() => _CommissionerWeekScreenState();
}

class _CommissionerWeekScreenState extends State<CommissionerWeekScreen> {
  late Future<WeekModel> _weekFuture;

  @override
  void initState() {
    super.initState();
    _weekFuture = context.read<WeekRepository>().getWeek(widget.weekId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Week Detail')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(
          'commissionerGames',
          pathParameters: {'weekId': widget.weekId},
        ),
        icon: const Icon(Icons.edit_calendar_outlined),
        label: const Text('Edit Games'),
      ),
      body: FutureBuilder<WeekModel>(
        future: _weekFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('Could not load this week.'));
          }
          final week = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Text(week.label, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text('Status: ${week.status.replaceAll('_', ' ')} · '
                  'Deadline: ${_formatDate(week.pickDeadline)}'),
              const SizedBox(height: 16),
              if (week.games.isEmpty)
                const Text('No games assigned yet.')
              else
                ...week.games.map(
                  (game) => Card(
                    child: ListTile(
                      title: Text('${game.awayTeam.abbreviation} @ ${game.homeTeam.abbreviation}'),
                      subtitle: Text(game.sport == 'college' ? 'College' : 'NFL'),
                      trailing: (game.spread != null || game.overUnder != null)
                          ? Text([
                              if (game.spread != null) 'Spread ${game.spread}',
                              if (game.overUnder != null) 'O/U ${game.overUnder}',
                            ].join(' · '))
                          : null,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static String _formatDate(DateTime dateTime) {
    final d = dateTime.toLocal();
    return '${d.month}/${d.day}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
