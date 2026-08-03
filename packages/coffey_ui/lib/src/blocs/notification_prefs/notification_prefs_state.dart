part of 'notification_prefs_cubit.dart';

@freezed
class NotificationPrefsState with _$NotificationPrefsState {
  const factory NotificationPrefsState.initial() = NotificationPrefsInitial;
  const factory NotificationPrefsState.loading() = NotificationPrefsLoading;

  const factory NotificationPrefsState.loaded({
    required NotificationPrefsModel prefs,
    String? errorMessage,
  }) = NotificationPrefsLoaded;

  const factory NotificationPrefsState.failure(String message) = NotificationPrefsFailure;
}
