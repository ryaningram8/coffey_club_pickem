part of 'game_selection_bloc.dart';

@freezed
class GameSelectionState with _$GameSelectionState {
  const factory GameSelectionState.initial() = GameSelectionInitial;
  const factory GameSelectionState.loading() = GameSelectionLoading;

  const factory GameSelectionState.loaded({
    required List<AvailableGameModel> available,
    required List<AvailableGameModel> selected,
    @Default(false) bool isPublishing,
  }) = GameSelectionLoaded;

  const factory GameSelectionState.published(WeekModel week) = GameSelectionPublished;
  const factory GameSelectionState.failure(String message) = GameSelectionFailure;
}
