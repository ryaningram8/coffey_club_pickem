import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import '../../models/pick_summary_model.dart';
import '../../models/season_standing_model.dart';
import '../../models/week_standing_model.dart';

part 'standings_api.g.dart';

@RestApi()
abstract class StandingsApi {
  factory StandingsApi(Dio dio, {String baseUrl}) = _StandingsApi;

  @GET('/weeks/{id}/standings')
  Future<List<WeekStandingModel>> getWeekStandings(@Path('id') String id);

  @GET('/weeks/{id}/picks/summary')
  Future<List<PickSummaryEntryModel>> getPicksSummary(@Path('id') String id);

  @GET('/seasons/{id}/standings')
  Future<List<SeasonStandingModel>> getSeasonStandings(@Path('id') String id);
}
