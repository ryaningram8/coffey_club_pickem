import 'package:freezed_annotation/freezed_annotation.dart';
import 'invitation_redeemer_model.dart';

part 'invitation_model.freezed.dart';
part 'invitation_model.g.dart';

@freezed
abstract class InvitationModel with _$InvitationModel {
  const factory InvitationModel({
    required String id,
    required String code,
    required String seasonId,
    required String seasonName,
    String? email,
    DateTime? expiresAt,
    required DateTime createdAt,
    int? maxUses,
    required int useCount,
    @Default([]) List<InvitationRedeemerModel> redeemedBy,
  }) = _InvitationModel;

  factory InvitationModel.fromJson(Map<String, dynamic> json) =>
      _$InvitationModelFromJson(json);
}
