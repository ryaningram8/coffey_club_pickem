import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import '../../models/season_model.dart';
import '../../models/week_summary_model.dart';

part 'season_api.g.dart';

@RestApi()
abstract class SeasonApi {
  factory SeasonApi(Dio dio, {String baseUrl}) = _SeasonApi;

  @GET('/seasons/active')
  Future<SeasonModel> getActiveSeason();

  @GET('/seasons/{id}')
  Future<SeasonModel> getSeason(@Path('id') String id);

  @GET('/seasons/{id}/weeks')
  Future<List<WeekSummaryModel>> getWeeks(@Path('id') String id);

  @POST('/seasons')
  Future<SeasonModel> createSeason(@Body() Map<String, dynamic> body);

  @POST('/seasons/{id}/weeks')
  Future<WeekSummaryModel> createWeek(@Path('id') String id, @Body() Map<String, dynamic> body);
}
