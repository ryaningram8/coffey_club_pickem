part of 'live_results_bloc.dart';

@freezed
class LiveResultsState with _$LiveResultsState {
  const factory LiveResultsState.initial() = LiveResultsInitial;
  const factory LiveResultsState.loading() = LiveResultsLoading;

  const factory LiveResultsState.loaded({
    required WeekModel week,
    required List<PickSummaryEntryModel> picksSummary,
    required WeekTiebreakerModel tiebreaker,
    required DateTime lastUpdated,
  }) = LiveResultsLoaded;

  const factory LiveResultsState.failure(String message) = LiveResultsFailure;
}
