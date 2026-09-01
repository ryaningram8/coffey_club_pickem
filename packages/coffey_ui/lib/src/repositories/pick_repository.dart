import '../models/pick_model.dart';
import '../services/api/pick_api.dart';
import '../services/api_client.dart';
import 'api_error_mapper.dart';

class PickRepository with ApiErrorMapper {
  PickRepository({required ApiClient apiClient}) : _api = PickApi(apiClient.dio);

  final PickApi _api;

  Future<List<PickModel>> getPicks(String weekId) => guard(() => _api.getPicks(weekId));

  Future<List<PickModel>> submitPicks(String weekId, List<PickModel> picks) {
    return guard(
      () => _api.submitPicks(weekId, {
        'picks': picks
            .map(
              (p) => {
                'gameId': p.gameId,
                'pickedTeamId': p.pickedTeamId,
                if (p.tiebreakerGuess != null) 'tiebreakerGuess': p.tiebreakerGuess,
              },
            )
            .toList(),
      }),
    );
  }

  /// Commissioner-only: another player's already-entered picks, to prefill
  /// the "enter picks for player" screen when that player is selected.
  Future<List<PickModel>> getPicksForPlayer(String weekId, String userId) =>
      guard(() => _api.getPicksForPlayer(weekId, userId));

  /// Commissioner-only: enters/overwrites another player's picks (paper
  /// pick sheet catch-up) — no pick-deadline enforcement on the backend.
  Future<List<PickModel>> submitPicksForPlayer(
    String weekId,
    String userId,
    List<PickModel> picks,
  ) {
    return guard(
      () => _api.submitPicksForPlayer(weekId, userId, {
        'picks': picks
            .map(
              (p) => {
                'gameId': p.gameId,
                'pickedTeamId': p.pickedTeamId,
                if (p.tiebreakerGuess != null) 'tiebreakerGuess': p.tiebreakerGuess,
              },
            )
            .toList(),
      }),
    );
  }
}
