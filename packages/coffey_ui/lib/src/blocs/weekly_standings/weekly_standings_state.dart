part of 'weekly_standings_bloc.dart';

@freezed
class WeeklyStandingsState with _$WeeklyStandingsState {
  const factory WeeklyStandingsState.initial() = WeeklyStandingsInitial;
  const factory WeeklyStandingsState.loading() = WeeklyStandingsLoading;

  const factory WeeklyStandingsState.loaded({
    required WeekModel week,
    required List<WeekStandingModel> standings,
    required List<PickSummaryEntryModel> picksSummary,
    String? expandedUserId,
  }) = WeeklyStandingsLoaded;

  const factory WeeklyStandingsState.failure(String message) = WeeklyStandingsFailure;
}
