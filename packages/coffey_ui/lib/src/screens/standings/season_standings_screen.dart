import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/selected_pool/selected_pool_cubit.dart';
import '../../models/season_standing_model.dart';
import '../../repositories/standings_repository.dart';

/// All-time leaderboard for the currently selected pool (see
/// SelectedPoolCubit). Simple fetch-and-display, so this uses FutureBuilder
/// rather than a dedicated BLoC — same reasoning as CommissionerWeekScreen.
class SeasonStandingsScreen extends StatefulWidget {
  const SeasonStandingsScreen({super.key});

  @override
  State<SeasonStandingsScreen> createState() => _SeasonStandingsScreenState();
}

class _SeasonStandingsScreenState extends State<SeasonStandingsScreen> {
  late Future<List<SeasonStandingModel>?> _standingsFuture;

  @override
  void initState() {
    super.initState();
    _standingsFuture = _load();
  }

  Future<List<SeasonStandingModel>?> _load() async {
    final poolState = context.read<SelectedPoolCubit>().state;
    if (poolState is! SelectedPoolLoaded) return null;
    final standingsRepository = context.read<StandingsRepository>();
    return standingsRepository.getSeasonStandings(poolState.selectedPoolId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Season Standings')),
      body: FutureBuilder<List<SeasonStandingModel>?>(
        future: _standingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load season standings.'));
          }
          final standings = snapshot.data;
          if (standings == null) {
            return const Center(child: Text('No active season yet.'));
          }
          if (standings.isEmpty) {
            return const Center(child: Text('No results yet this season.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: standings.length,
            itemBuilder: (context, index) {
              final s = standings[index];
              final rank = index == 0 || s.totalCorrect != standings[index - 1].totalCorrect
                  ? index + 1
                  : null;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                  foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                  child: Text(rank?.toString() ?? '='),
                ),
                title: Text(s.userName),
                subtitle: Text('${s.totalCorrect} correct across ${s.weeksPlayed} weeks'),
                trailing: Text(
                  '\$${double.parse(s.totalPayout).toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
