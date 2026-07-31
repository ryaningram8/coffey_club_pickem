import '../models/available_game_model.dart';
import '../models/game_model.dart';
import '../services/api/game_api.dart';
import '../services/api_client.dart';
import 'api_error_mapper.dart';

class GameRepository with ApiErrorMapper {
  GameRepository({required ApiClient apiClient}) : _api = GameApi(apiClient.dio);

  final GameApi _api;

  Future<List<AvailableGameModel>> getAvailableGames({String? sport}) =>
      guard(() => _api.getAvailableGames(sport));

  Future<GameModel> updateGame(
    String id, {
    DateTime? gameTime,
    double? spread,
    double? overUnder,
    String? status,
    int? displayOrder,
  }) {
    return guard(
      () => _api.updateGame(id, {
        if (gameTime != null) 'gameTime': gameTime.toUtc().toIso8601String(),
        'spread': ?spread,
        'overUnder': ?overUnder,
        'status': ?status,
        'displayOrder': ?displayOrder,
      }),
    );
  }

  Future<void> deleteGame(String id) => guard(() => _api.deleteGame(id));
}
