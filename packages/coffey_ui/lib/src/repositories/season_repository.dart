import '../models/api_exception.dart';
import '../models/season_model.dart';
import '../models/week_summary_model.dart';
import '../services/api/season_api.dart';
import '../services/api_client.dart';
import 'api_error_mapper.dart';

class SeasonRepository with ApiErrorMapper {
  SeasonRepository({required ApiClient apiClient}) : _api = SeasonApi(apiClient.dio);

  final SeasonApi _api;

  /// Null when no active or upcoming season exists yet (off-season empty state).
  Future<SeasonModel?> getActiveSeason() async {
    try {
      return await guard(() => _api.getActiveSeason());
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  Future<SeasonModel> getSeason(String id) => guard(() => _api.getSeason(id));

  Future<List<WeekSummaryModel>> getWeeks(String seasonId) =>
      guard(() => _api.getWeeks(seasonId));

  Future<SeasonModel> createSeason({
    required String name,
    required int year,
    double? entryFee,
    double? payout1stPct,
    double? payout2ndPct,
    double? payout3rdPct,
  }) {
    return guard(
      () => _api.createSeason({
        'name': name,
        'year': year,
        'entryFee': ?entryFee,
        'payout1stPct': ?payout1stPct,
        'payout2ndPct': ?payout2ndPct,
        'payout3rdPct': ?payout3rdPct,
      }),
    );
  }

  Future<WeekSummaryModel> createWeek(
    String seasonId, {
    required int weekNumber,
    required String label,
    required DateTime pickDeadline,
  }) {
    return guard(
      () => _api.createWeek(seasonId, {
        'weekNumber': weekNumber,
        'label': label,
        'pickDeadline': pickDeadline.toUtc().toIso8601String(),
      }),
    );
  }
}
