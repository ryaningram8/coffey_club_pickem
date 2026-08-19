import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../models/pick_summary_model.dart';
import '../../models/week_model.dart';
import '../../models/week_standing_model.dart';
import '../../repositories/standings_repository.dart';
import '../../repositories/week_repository.dart';

part 'weekly_standings_bloc.freezed.dart';
part 'weekly_standings_event.dart';
part 'weekly_standings_state.dart';

class WeeklyStandingsBloc
    extends Bloc<WeeklyStandingsEvent, WeeklyStandingsState> {
  WeeklyStandingsBloc({
    required WeekRepository weekRepository,
    required StandingsRepository standingsRepository,
    required String weekId,
  }) : _weekRepository = weekRepository,
       _standingsRepository = standingsRepository,
       _weekId = weekId,
       super(const WeeklyStandingsState.initial()) {
    on<WeeklyStandingsStarted>(_onStarted);
    on<WeeklyStandingsPlayerToggled>(_onPlayerToggled);
  }

  final WeekRepository _weekRepository;
  final StandingsRepository _standingsRepository;
  final String _weekId;

  Future<void> _onStarted(
    WeeklyStandingsStarted event,
    Emitter<WeeklyStandingsState> emit,
  ) async {
    emit(const WeeklyStandingsState.loading());
    try {
      final week = await _weekRepository.getWeek(_weekId);
      final standings = await _standingsRepository.getWeekStandings(_weekId);
      final picksSummary = await _standingsRepository.getPicksSummary(_weekId);
      emit(
        WeeklyStandingsState.loaded(
          week: week,
          standings: standings,
          picksSummary: picksSummary,
        ),
      );
    } catch (e) {
      emit(WeeklyStandingsState.failure(e.toString()));
    }
  }

  void _onPlayerToggled(
    WeeklyStandingsPlayerToggled event,
    Emitter<WeeklyStandingsState> emit,
  ) {
    final current = state;
    if (current is! WeeklyStandingsLoaded) return;
    final isSame = current.expandedUserId == event.userId;
    emit(current.copyWith(expandedUserId: isSame ? null : event.userId));
  }
}
