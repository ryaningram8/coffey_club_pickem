import '../models/api_exception.dart';
import '../models/roster_member_model.dart';
import '../models/season_model.dart';
import '../models/week_summary_model.dart';
import '../services/api/season_api.dart';
import '../services/api_client.dart';
import 'api_error_mapper.dart';

class SeasonRepository with ApiErrorMapper {
  SeasonRepository({required ApiClient apiClient}) : _api = SeasonApi(apiClient.dio);

  final SeasonApi _api;

  Future<List<SeasonModel>> getSeasons() => guard(() => _api.getSeasons());

  /// Pools the current user has actually joined, each with their role in
  /// it — the non-admin counterpart to [getSeasons], used by the pool
  /// switcher.
  Future<List<SeasonModel>> getMySeasons() => guard(() => _api.getMySeasons());

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

  /// A season's roster (name/email/role per member) — used by the
  /// commissioner "enter picks for player" player picker.
  Future<List<RosterMemberModel>> getMembers(String seasonId) =>
      guard(() => _api.getMembers(seasonId));

  /// Creates a shell account (name + email, no login yet) for a player with
  /// no `User` row at all, enrolled in [seasonId] — the "Create Player"
  /// option in the commissioner "enter picks for player" player picker.
  Future<RosterMemberModel> createShellMember(
    String seasonId, {
    required String name,
    required String email,
  }) {
    return guard(
      () => _api.createShellMember(seasonId, {'name': name, 'email': email}),
    );
  }

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
