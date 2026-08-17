import '../models/admin_membership_model.dart';
import '../models/admin_user_model.dart';
import '../services/api/admin_users_api.dart';
import '../services/api_client.dart';
import 'api_error_mapper.dart';

class AdminUsersRepository with ApiErrorMapper {
  AdminUsersRepository({required ApiClient apiClient}) : _api = AdminUsersApi(apiClient.dio);

  final AdminUsersApi _api;

  Future<List<AdminUserModel>> getUsers() => guard(() => _api.getUsers());

  Future<AdminMembershipModel> updateMembershipRole({
    required String userId,
    required String seasonId,
    required String role,
  }) {
    return guard(
      () => _api.updateMembershipRole(userId, seasonId, {'role': role}),
    );
  }

  Future<void> removeMembership({required String userId, required String seasonId}) =>
      guard(() => _api.removeMembership(userId, seasonId));
}
