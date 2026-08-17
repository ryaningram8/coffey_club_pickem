part of 'selected_pool_cubit.dart';

@freezed
class SelectedPoolState with _$SelectedPoolState {
  const factory SelectedPoolState.initial() = SelectedPoolInitial;
  const factory SelectedPoolState.loading() = SelectedPoolLoading;

  /// The user (not admin) hasn't joined any pool yet.
  const factory SelectedPoolState.noPools() = SelectedPoolNoPools;

  const factory SelectedPoolState.loaded({
    required List<SeasonModel> pools,
    required String selectedPoolId,
    @Default(false) bool isJoiningPool,
  }) = SelectedPoolLoaded;

  const factory SelectedPoolState.failure(String message) = SelectedPoolFailure;
}
