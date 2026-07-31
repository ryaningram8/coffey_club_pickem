import '../models/pick_summary_model.dart';
import '../models/season_standing_model.dart';
import '../models/week_standing_model.dart';
import '../services/api/standings_api.dart';
import '../services/api_client.dart';
import 'api_error_mapper.dart';

class StandingsRepository with ApiErrorMapper {
  StandingsRepository({required ApiClient apiClient}) : _api = StandingsApi(apiClient.dio);

  final StandingsApi _api;

  /// Empty until every game in the week is final — WeeklyResult rows are
  /// only written by WeekCompleteJob once the week is fully done.
  Future<List<WeekStandingModel>> getWeekStandings(String weekId) =>
      guard(() => _api.getWeekStandings(weekId));

  /// Per-user pick correctness updates live as each game finalizes, so this
  /// is the source for in-progress leaderboards, unlike getWeekStandings.
  Future<List<PickSummaryEntryModel>> getPicksSummary(String weekId) =>
      guard(() => _api.getPicksSummary(weekId));

  Future<List<SeasonStandingModel>> getSeasonStandings(String seasonId) =>
      guard(() => _api.getSeasonStandings(seasonId));
}
