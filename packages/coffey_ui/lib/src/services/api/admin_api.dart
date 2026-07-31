import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import '../../models/week_standing_model.dart';

part 'admin_api.g.dart';

@RestApi()
abstract class AdminApi {
  factory AdminApi(Dio dio, {String baseUrl}) = _AdminApi;

  @POST('/admin/payouts/{weekId}/mark')
  Future<WeekStandingModel> markPayout(
    @Path('weekId') String weekId,
    @Body() Map<String, dynamic> body,
  );
}
