part of 'enter_picks_bloc.dart';

@freezed
class EnterPicksEvent with _$EnterPicksEvent {
  const factory EnterPicksEvent.started() = EnterPicksStarted;
  const factory EnterPicksEvent.playerSelected(String userId) =
      EnterPicksPlayerSelected;
  const factory EnterPicksEvent.teamSelected({
    required String gameId,
    required String teamId,
  }) = EnterPicksTeamSelected;
  const factory EnterPicksEvent.tiebreakerGuessChanged({
    required String gameId,
    int? guess,
  }) = EnterPicksTiebreakerGuessChanged;
  const factory EnterPicksEvent.submitRequested() = EnterPicksSubmitRequested;
  const factory EnterPicksEvent.playerCreated({
    required String name,
    required String email,
  }) = EnterPicksPlayerCreated;
}
