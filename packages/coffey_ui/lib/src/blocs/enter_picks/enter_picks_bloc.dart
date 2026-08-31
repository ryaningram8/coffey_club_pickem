import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../models/pick_model.dart';
import '../../models/roster_member_model.dart';
import '../../models/week_model.dart';
import '../../repositories/pick_repository.dart';
import '../../repositories/season_repository.dart';
import '../../repositories/week_repository.dart';

part 'enter_picks_bloc.freezed.dart';
part 'enter_picks_event.dart';
part 'enter_picks_state.dart';

/// Commissioner-only "enter picks for player" flow (paper pick sheet
/// catch-up). Structurally a hybrid of [PicksBloc]'s week/games/selections
/// shape and a pool-filter-style selector: a [selectedPlayerId] on top,
/// whose change re-fetches that player's already-entered picks. Unlike
/// the self-pick flow, submission isn't deadline-gated and doesn't require
/// every game to be picked — a physical paper sheet may legitimately have
/// blanks, and each pick upserts independently on the backend.
class EnterPicksBloc extends Bloc<EnterPicksEvent, EnterPicksState> {
  EnterPicksBloc({
    required WeekRepository weekRepository,
    required PickRepository pickRepository,
    required SeasonRepository seasonRepository,
    required String weekId,
  }) : _weekRepository = weekRepository,
       _pickRepository = pickRepository,
       _seasonRepository = seasonRepository,
       _weekId = weekId,
       super(const EnterPicksState.initial()) {
    on<EnterPicksStarted>(_onStarted);
    on<EnterPicksPlayerSelected>(_onPlayerSelected);
    on<EnterPicksTeamSelected>(_onTeamSelected);
    on<EnterPicksSubmitRequested>(_onSubmitRequested);
  }

  final WeekRepository _weekRepository;
  final PickRepository _pickRepository;
  final SeasonRepository _seasonRepository;
  final String _weekId;

  Future<void> _onStarted(
    EnterPicksStarted event,
    Emitter<EnterPicksState> emit,
  ) async {
    emit(const EnterPicksState.loading());
    try {
      final week = await _weekRepository.getWeek(_weekId);
      final roster = await _seasonRepository.getMembers(week.seasonId);
      emit(
        EnterPicksState.loaded(
          week: week,
          roster: roster,
          selections: const {},
        ),
      );
    } catch (e) {
      emit(EnterPicksState.failure(e.toString()));
    }
  }

  Future<void> _onPlayerSelected(
    EnterPicksPlayerSelected event,
    Emitter<EnterPicksState> emit,
  ) async {
    final current = state;
    if (current is! EnterPicksLoaded) return;
    emit(
      current.copyWith(
        selectedPlayerId: event.userId,
        selections: const {},
        justSubmitted: false,
        errorMessage: null,
      ),
    );
    try {
      final picks = await _pickRepository.getPicksForPlayer(
        _weekId,
        event.userId,
      );
      final latest = state;
      // The commissioner may have already switched to a different player
      // by the time this resolves — only apply it if still relevant.
      if (latest is EnterPicksLoaded && latest.selectedPlayerId == event.userId) {
        final selections = {for (final p in picks) p.gameId: p.pickedTeamId};
        emit(latest.copyWith(selections: selections));
      }
    } catch (e) {
      final latest = state;
      if (latest is EnterPicksLoaded && latest.selectedPlayerId == event.userId) {
        emit(latest.copyWith(errorMessage: e.toString()));
      }
    }
  }

  void _onTeamSelected(
    EnterPicksTeamSelected event,
    Emitter<EnterPicksState> emit,
  ) {
    final current = state;
    if (current is! EnterPicksLoaded) return;
    final updated = Map<String, String>.from(current.selections)
      ..[event.gameId] = event.teamId;
    emit(current.copyWith(selections: updated, justSubmitted: false));
  }

  Future<void> _onSubmitRequested(
    EnterPicksSubmitRequested event,
    Emitter<EnterPicksState> emit,
  ) async {
    final current = state;
    if (current is! EnterPicksLoaded) return;
    final playerId = current.selectedPlayerId;
    if (playerId == null || current.selections.isEmpty) return;

    emit(current.copyWith(isSubmitting: true, errorMessage: null));
    try {
      final picks = current.selections.entries
          .map((e) => PickModel(gameId: e.key, pickedTeamId: e.value))
          .toList();
      await _pickRepository.submitPicksForPlayer(_weekId, playerId, picks);
      emit(current.copyWith(isSubmitting: false, justSubmitted: true));
    } catch (e) {
      emit(current.copyWith(isSubmitting: false, errorMessage: e.toString()));
    }
  }
}
