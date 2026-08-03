import '../models/notification_prefs_model.dart';
import '../services/api/notification_api.dart';
import '../services/api_client.dart';
import 'api_error_mapper.dart';

class NotificationRepository with ApiErrorMapper {
  NotificationRepository({required ApiClient apiClient}) : _api = NotificationApi(apiClient.dio);

  final NotificationApi _api;

  Future<NotificationPrefsModel> getPrefs() => guard(() => _api.getPrefs());

  Future<NotificationPrefsModel> updatePrefs({
    Map<String, dynamic>? pickReminders,
    Map<String, dynamic>? resultsNotifications,
  }) {
    return guard(
      () => _api.updatePrefs({
        'pickReminders': ?pickReminders,
        'resultsNotifications': ?resultsNotifications,
      }),
    );
  }

  Future<void> registerFcmToken(String token) =>
      guard(() => _api.registerFcmToken({'token': token}));
}
