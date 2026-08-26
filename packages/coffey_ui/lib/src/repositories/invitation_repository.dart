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

  /// `maxUses`: how many different people may redeem the code — defaults to
  /// 1 (a traditional one-person code). Pass a higher number, or `null` for
  /// unlimited, to mint one shared code a whole group can all redeem.
  /// Always sent explicitly (even when `null`) since `null` is a meaningful
  /// "unlimited" value here, not an absent one.
  Future<List<InvitationModel>> createInvitations({
    required String seasonId,
    String? email,
    DateTime? expiresAt,
    int? count,
    int? maxUses = 1,
  }) {
    return guard(
      () => _api.createInvitations({
        'seasonId': seasonId,
        'email': ?email,
        'expiresAt': ?expiresAt?.toUtc().toIso8601String(),
        'count': ?count,
        'maxUses': maxUses,
      }),
    );
  }
}
