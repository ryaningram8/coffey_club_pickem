part of 'commissioner_bloc.dart';

@freezed
class CommissionerState with _$CommissionerState {
  const factory CommissionerState.initial() = CommissionerInitial;
  const factory CommissionerState.loading() = CommissionerLoading;

  /// No active or upcoming season exists yet.
  const factory CommissionerState.empty() = CommissionerEmpty;

  const factory CommissionerState.loaded({
    required SeasonModel season,
    required List<WeekSummaryModel> weeks,
    @Default(false) bool isCreatingWeek,
  }) = CommissionerLoaded;

  const factory CommissionerState.failure(String message) = CommissionerFailure;
}
