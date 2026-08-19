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
  }

  final GameRepository _gameRepository;
  final WeekRepository _weekRepository;
  final String _weekId;

  Future<void> _onStarted(
    GameSelectionStarted event,
    Emitter<GameSelectionState> emit,
  ) async {
    emit(const GameSelectionState.loading());
    try {
      final available = await _gameRepository.getAvailableGames();
      emit(GameSelectionState.loaded(available: available, selected: const []));
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
