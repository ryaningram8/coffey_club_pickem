import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../models/season_model.dart';
import '../../models/week_summary_model.dart';
import '../../repositories/season_repository.dart';

part 'commissioner_bloc.freezed.dart';
part 'commissioner_event.dart';
part 'commissioner_state.dart';

class CommissionerBloc extends Bloc<CommissionerEvent, CommissionerState> {
  CommissionerBloc({required SeasonRepository seasonRepository})
      : _seasonRepository = seasonRepository,
        super(const CommissionerState.initial()) {
    on<CommissionerStarted>(_onStarted);
    on<CommissionerWeekCreateRequested>(_onWeekCreateRequested);
  }

  final SeasonRepository _seasonRepository;

  Future<void> _onStarted(
    CommissionerStarted event,
    Emitter<CommissionerState> emit,
  ) async {
    emit(const CommissionerState.loading());
    await _loadWeeks(emit);
  }

  Future<void> _onWeekCreateRequested(
    CommissionerWeekCreateRequested event,
    Emitter<CommissionerState> emit,
  ) async {
    final current = state;
    if (current is! CommissionerLoaded) return;
    emit(current.copyWith(isCreatingWeek: true));
    try {
      await _seasonRepository.createWeek(
        current.season.id,
        weekNumber: event.weekNumber,
        label: event.label,
        pickDeadline: event.pickDeadline,
      );
      await _loadWeeks(emit);
    } catch (e) {
      emit(CommissionerState.failure(e.toString()));
    }
  }

  Future<void> _loadWeeks(Emitter<CommissionerState> emit) async {
    try {
      final season = await _seasonRepository.getActiveSeason();
      if (season == null) {
        emit(const CommissionerState.empty());
        return;
      }
      final weeks = await _seasonRepository.getWeeks(season.id);
      emit(CommissionerState.loaded(season: season, weeks: weeks));
    } catch (e) {
      emit(CommissionerState.failure(e.toString()));
    }
  }
}
