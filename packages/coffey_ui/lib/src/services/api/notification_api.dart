import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import '../../models/notification_prefs_model.dart';

part 'notification_api.g.dart';

@RestApi()
abstract class NotificationApi {
  factory NotificationApi(Dio dio, {String baseUrl}) = _NotificationApi;

  @GET('/users/me/notifications')
  Future<NotificationPrefsModel> getPrefs();

  @PUT('/users/me/notifications')
  Future<NotificationPrefsModel> updatePrefs(@Body() Map<String, dynamic> body);

  @POST('/users/me/fcm-token')
  Future<void> registerFcmToken(@Body() Map<String, dynamic> body);
}
