import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../models/pick_model.dart';
import '../../models/week_model.dart';
import '../../repositories/pick_repository.dart';
import '../../repositories/week_repository.dart';

part 'picks_bloc.freezed.dart';
part 'picks_event.dart';
part 'picks_state.dart';

class PicksBloc extends Bloc<PicksEvent, PicksState> {
  PicksBloc({
    required WeekRepository weekRepository,
    required PickRepository pickRepository,
    required String weekId,
  }) : _weekRepository = weekRepository,
       _pickRepository = pickRepository,
       _weekId = weekId,
       super(const PicksState.initial()) {
    on<PicksStarted>(_onStarted);
    on<PicksTeamSelected>(_onTeamSelected);
    on<PicksSubmitRequested>(_onSubmitRequested);
  }

  final WeekRepository _weekRepository;
  final PickRepository _pickRepository;
  final String _weekId;

  Future<void> _onStarted(PicksStarted event, Emitter<PicksState> emit) async {
    emit(const PicksState.loading());
    try {
      final week = await _weekRepository.getWeek(_weekId);
      final existingPicks = await _pickRepository.getPicks(_weekId);
      final selections = {
        for (final p in existingPicks) p.gameId: p.pickedTeamId,
      };
      emit(PicksState.loaded(week: week, selections: selections));
    } catch (e) {
      emit(PicksState.failure(e.toString()));
    }
  }

  void _onTeamSelected(PicksTeamSelected event, Emitter<PicksState> emit) {
    final current = state;
    if (current is! PicksLoaded) return;
    final updated = Map<String, String>.from(current.selections)
      ..[event.gameId] = event.teamId;
    emit(current.copyWith(selections: updated, justSubmitted: false));
  }

  Future<void> _onSubmitRequested(
    PicksSubmitRequested event,
    Emitter<PicksState> emit,
  ) async {
    final current = state;
    if (current is! PicksLoaded) return;
    emit(current.copyWith(isSubmitting: true, errorMessage: null));
    try {
      final picks = current.selections.entries
          .map((e) => PickModel(gameId: e.key, pickedTeamId: e.value))
          .toList();
      await _pickRepository.submitPicks(_weekId, picks);
      emit(current.copyWith(isSubmitting: false, justSubmitted: true));
    } catch (e) {
      emit(current.copyWith(isSubmitting: false, errorMessage: e.toString()));
    }
  }
}
