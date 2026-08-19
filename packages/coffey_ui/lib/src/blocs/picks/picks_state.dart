part of 'picks_bloc.dart';

@freezed
class PicksState with _$PicksState {
  const factory PicksState.initial() = PicksInitial;
  const factory PicksState.loading() = PicksLoading;

  const factory PicksState.loaded({
    required WeekModel week,

    /// gameId -> pickedTeamId
    required Map<String, String> selections,
    @Default(false) bool isSubmitting,
    @Default(false) bool justSubmitted,
    String? errorMessage,
  }) = PicksLoaded;

  const factory PicksState.failure(String message) = PicksFailure;
}
