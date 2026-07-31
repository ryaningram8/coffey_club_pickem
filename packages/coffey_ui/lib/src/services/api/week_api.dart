import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import '../../models/week_model.dart';

part 'week_api.g.dart';

@RestApi()
abstract class WeekApi {
  factory WeekApi(Dio dio, {String baseUrl}) = _WeekApi;

  @GET('/weeks/current')
  Future<WeekModel> getCurrentWeek();

  @GET('/weeks/{id}')
  Future<WeekModel> getWeek(@Path('id') String id);

  @PUT('/weeks/{id}')
  Future<WeekModel> updateWeek(@Path('id') String id, @Body() Map<String, dynamic> body);

  @POST('/weeks/{id}/games')
  Future<WeekModel> assignGames(@Path('id') String id, @Body() Map<String, dynamic> body);
}
