part of 'picks_bloc.dart';

@freezed
class PicksEvent with _$PicksEvent {
  const factory PicksEvent.started() = PicksStarted;
  const factory PicksEvent.teamSelected({
    required String gameId,
    required String teamId,
  }) = PicksTeamSelected;
  const factory PicksEvent.submitRequested() = PicksSubmitRequested;
}
