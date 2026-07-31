import '../models/week_standing_model.dart';
import '../services/api/admin_api.dart';
import '../services/api_client.dart';
import 'api_error_mapper.dart';

class PayoutRepository with ApiErrorMapper {
  PayoutRepository({required ApiClient apiClient}) : _api = AdminApi(apiClient.dio);

  final AdminApi _api;

  Future<WeekStandingModel> markPayout(String weekId, String userId, bool isPaid) {
    return guard(
      () => _api.markPayout(weekId, {'userId': userId, 'isPaid': isPaid}),
    );
  }
}
