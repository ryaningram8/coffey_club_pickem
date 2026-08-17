import 'package:freezed_annotation/freezed_annotation.dart';

part 'invitation_redemption_model.freezed.dart';
part 'invitation_redemption_model.g.dart';

/// Result of redeeming an invite code — the pool the user just joined.
@freezed
abstract class InvitationRedemptionModel with _$InvitationRedemptionModel {
  const factory InvitationRedemptionModel({
    required String seasonId,
    required String seasonName,
  }) = _InvitationRedemptionModel;

  factory InvitationRedemptionModel.fromJson(Map<String, dynamic> json) =>
      _$InvitationRedemptionModelFromJson(json);
}
