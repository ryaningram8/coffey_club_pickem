part of 'payouts_bloc.dart';

@freezed
class PayoutsState with _$PayoutsState {
  const factory PayoutsState.initial() = PayoutsInitial;
  const factory PayoutsState.loading() = PayoutsLoading;

  const factory PayoutsState.loaded({
    required List<WeekStandingModel> standings,
    String? updatingUserId,
    String? errorMessage,
  }) = PayoutsLoaded;

  const factory PayoutsState.failure(String message) = PayoutsFailure;
}
