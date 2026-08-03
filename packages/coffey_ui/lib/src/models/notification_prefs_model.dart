import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_prefs_model.freezed.dart';
part 'notification_prefs_model.g.dart';

@freezed
abstract class PickReminderPrefsModel with _$PickReminderPrefsModel {
  const factory PickReminderPrefsModel({
    required bool enabled,
    required bool push,
    required bool email,
    required int hoursBeforeDeadline,
  }) = _PickReminderPrefsModel;

  factory PickReminderPrefsModel.fromJson(Map<String, dynamic> json) =>
      _$PickReminderPrefsModelFromJson(json);
}

@freezed
abstract class ResultsNotificationPrefsModel with _$ResultsNotificationPrefsModel {
  const factory ResultsNotificationPrefsModel({
    required bool enabled,
    required bool push,
    required bool email,
  }) = _ResultsNotificationPrefsModel;

  factory ResultsNotificationPrefsModel.fromJson(Map<String, dynamic> json) =>
      _$ResultsNotificationPrefsModelFromJson(json);
}

@freezed
abstract class NotificationPrefsModel with _$NotificationPrefsModel {
  const factory NotificationPrefsModel({
    required PickReminderPrefsModel pickReminders,
    required ResultsNotificationPrefsModel resultsNotifications,
  }) = _NotificationPrefsModel;

  factory NotificationPrefsModel.fromJson(Map<String, dynamic> json) =>
      _$NotificationPrefsModelFromJson(json);
}
