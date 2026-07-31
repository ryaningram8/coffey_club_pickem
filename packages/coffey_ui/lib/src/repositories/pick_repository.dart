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
        'picks': picks.map((p) => {'gameId': p.gameId, 'pickedTeamId': p.pickedTeamId}).toList(),
      }),
    );
  }
}
