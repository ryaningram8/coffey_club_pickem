import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../models/available_game_model.dart';
import '../../models/week_model.dart';
import '../../repositories/game_repository.dart';
import '../../repositories/week_repository.dart';

part 'game_selection_bloc.freezed.dart';
part 'game_selection_event.dart';
part 'game_selection_state.dart';

class GameSelectionBloc extends Bloc<GameSelectionEvent, GameSelectionState> {
  GameSelectionBloc({
    required GameRepository gameRepository,
    required WeekRepository weekRepository,
    required String weekId,
  }) : _gameRepository = gameRepository,
       _weekRepository = weekRepository,
       _weekId = weekId,
       super(const GameSelectionState.initial()) {
    on<GameSelectionStarted>(_onStarted);
    on<GameSelectionGameToggled>(_onGameToggled);
    on<GameSelectionPublishRequested>(_onPublishRequested);
    on<GameSelectionDateRangeChanged>(_onDateRangeChanged);
  }

  final GameRepository _gameRepository;
  final WeekRepository _weekRepository;
  final String _weekId;

  // Matches the backend's own default window (see defaultDateRange in
  // game.service.ts) so the date pickers show a sensible starting range.
  static const _defaultWindow = Duration(days: 8);

  Future<void> _onStarted(
    GameSelectionStarted event,
    Emitter<GameSelectionState> emit,
  ) async {
    emit(const GameSelectionState.loading());
    final startDate = DateTime.now();
    final endDate = startDate.add(_defaultWindow);
    try {
      final available = await _gameRepository.getAvailableGames(
        startDate: startDate,
        endDate: endDate,
      );
      emit(
        GameSelectionState.loaded(
          available: available,
          selected: const [],
          startDate: startDate,
          endDate: endDate,
        ),
      );
    } catch (e) {
      emit(GameSelectionState.failure(e.toString()));
    }
  }

  Future<void> _onDateRangeChanged(
    GameSelectionDateRangeChanged event,
    Emitter<GameSelectionState> emit,
  ) async {
    final current = state;
    if (current is! GameSelectionLoaded) return;
    emit(current.copyWith(isRefetching: true));
    try {
      final available = await _gameRepository.getAvailableGames(
        startDate: event.startDate,
        endDate: event.endDate,
      );
      emit(
        current.copyWith(
          available: available,
          startDate: event.startDate,
          endDate: event.endDate,
          isRefetching: false,
        ),
      );
    } catch (e) {
      emit(GameSelectionState.failure(e.toString()));
    }
  }

  void _onGameToggled(
    GameSelectionGameToggled event,
    Emitter<GameSelectionState> emit,
  ) {
    final current = state;
    if (current is! GameSelectionLoaded) return;
    final isSelected = current.selected.any(
      (g) => g.espnGameId == event.game.espnGameId,
    );
    final updated = isSelected
        ? current.selected
              .where((g) => g.espnGameId != event.game.espnGameId)
              .toList()
        : [...current.selected, event.game];
    emit(current.copyWith(selected: updated));
  }

  Future<void> _onPublishRequested(
    GameSelectionPublishRequested event,
    Emitter<GameSelectionState> emit,
  ) async {
    final current = state;
    if (current is! GameSelectionLoaded) return;
    emit(current.copyWith(isPublishing: true));
    try {
      final week = await _weekRepository.assignGames(_weekId, current.selected);
      emit(GameSelectionState.published(week));
    } catch (e) {
      emit(GameSelectionState.failure(e.toString()));
    }
  }
}
