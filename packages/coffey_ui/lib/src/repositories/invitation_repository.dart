import '../models/invitation_model.dart';
import '../models/invitation_redemption_model.dart';
import '../services/api/invitation_api.dart';
import '../services/api_client.dart';
import 'api_error_mapper.dart';

class InvitationRepository with ApiErrorMapper {
  InvitationRepository({required ApiClient apiClient}) : _api = InvitationApi(apiClient.dio);

  final InvitationApi _api;

  Future<List<InvitationModel>> getInvitations(String seasonId) =>
      guard(() => _api.getInvitations(seasonId));

  /// Lets an already-logged-in user join an additional pool via an invite
  /// code, without creating a new account.
  Future<InvitationRedemptionModel> redeemInvitation(String code) =>
      guard(() => _api.redeemInvitation(code));

  Future<List<InvitationModel>> createInvitations({
    required String seasonId,
    String? email,
    DateTime? expiresAt,
    int? count,
  }) {
    return guard(
      () => _api.createInvitations({
        'seasonId': seasonId,
        'email': ?email,
        'expiresAt': ?expiresAt?.toUtc().toIso8601String(),
        'count': ?count,
      }),
    );
  }
}
