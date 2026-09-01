import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../models/api_exception.dart';
import '../models/available_game_model.dart';
import '../models/week_model.dart';
import '../services/api/week_api.dart';
import '../services/api_client.dart';
import 'api_error_mapper.dart';

class WeekRepository with ApiErrorMapper {
  WeekRepository({required ApiClient apiClient})
      : _api = WeekApi(apiClient.dio),
        _dio = apiClient.dio;

  final WeekApi _api;
  final Dio _dio;

  /// Null when there's no active or upcoming week in this pool (off-season
  /// empty state) — the backend 404s in that case, which we translate to
  /// null here so callers don't have to special-case an ApiException.
  Future<WeekModel?> getCurrentWeek(String seasonId) async {
    try {
      return await guard(() => _api.getCurrentWeek(seasonId));
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  Future<WeekModel> getWeek(String id) => guard(() => _api.getWeek(id));

  Future<WeekModel> updateWeek(
    String id, {
    String? label,
    DateTime? pickDeadline,
    String? status,
  }) {
    return guard(
      () => _api.updateWeek(id, {
        'label': ?label,
        if (pickDeadline != null) 'pickDeadline': pickDeadline.toUtc().toIso8601String(),
        'status': ?status,
      }),
    );
  }

  /// Separate from [updateWeek] since its `'label': ?label` include-if-present
  /// pattern can't express "explicitly clear to null" — this always sends
  /// the field, null included, mirroring PayoutRepository.markPayout's
  /// single-purpose shape.
  Future<WeekModel> updateCommissionerMessage(String weekId, String? message) {
    return guard(() => _api.updateWeek(weekId, {'commissionerMessage': message}));
  }

  /// Same single-purpose shape as [updateCommissionerMessage] — always sends
  /// `pot`, null included, so clearing it back out is possible.
  Future<WeekModel> updatePot(String weekId, double? pot) {
    return guard(() => _api.updateWeek(weekId, {'pot': pot}));
  }

  Future<void> deleteWeek(String weekId) => guard(() => _api.deleteWeek(weekId));

  Future<WeekModel> assignGames(String weekId, List<AvailableGameModel> games) {
    Map<String, dynamic> team(AvailableTeamModel t) => {
          'espnId': t.espnId,
          'name': t.name,
          'abbreviation': t.abbreviation,
          'logoUrl': ?t.logoUrl,
        };

    final payload = games
        .map(
          (g) => {
            'espnGameId': g.espnGameId,
            'sport': g.sport,
            'gameTime': g.gameTime.toUtc().toIso8601String(),
            'homeTeam': team(g.homeTeam),
            'awayTeam': team(g.awayTeam),
            'spread': ?g.spread,
            'overUnder': ?g.overUnder,
            'isNeutralSite': g.isNeutralSite,
            'venueName': ?g.venueName,
            'venueCity': ?g.venueCity,
            'venueCountry': ?g.venueCountry,
            'network': ?g.network,
          },
        )
        .toList();
    return guard(() => _api.assignGames(weekId, {'games': payload}));
  }

  /// Raw call rather than a Retrofit method — no binary response exists
  /// anywhere else in this app's API layer, and a plain Dio call is a
  /// smaller addition than teaching Retrofit a non-JSON response type here.
  Future<Uint8List> downloadPickSheetPdf(String weekId) {
    return guard(() async {
      final response = await _dio.get<List<int>>(
        '/weeks/$weekId/pick-sheet.pdf',
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data!);
    });
  }
}
