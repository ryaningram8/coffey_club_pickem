part of 'game_selection_bloc.dart';

@freezed
class GameSelectionEvent with _$GameSelectionEvent {
  const factory GameSelectionEvent.started() = GameSelectionStarted;
  const factory GameSelectionEvent.gameToggled(AvailableGameModel game) =
      GameSelectionGameToggled;
  const factory GameSelectionEvent.publishRequested() = GameSelectionPublishRequested;
}
