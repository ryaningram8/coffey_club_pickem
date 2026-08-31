part of 'enter_picks_bloc.dart';

@freezed
class EnterPicksState with _$EnterPicksState {
  const factory EnterPicksState.initial() = EnterPicksInitial;
  const factory EnterPicksState.loading() = EnterPicksLoading;

  const factory EnterPicksState.loaded({
    required WeekModel week,
    required List<RosterMemberModel> roster,
    String? selectedPlayerId,

    /// gameId -> pickedTeamId, for [selectedPlayerId].
    required Map<String, String> selections,
    @Default(false) bool isSubmitting,
    @Default(false) bool justSubmitted,
    String? errorMessage,
  }) = EnterPicksLoaded;

  const factory EnterPicksState.failure(String message) = EnterPicksFailure;
}
