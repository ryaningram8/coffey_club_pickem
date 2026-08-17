import 'package:freezed_annotation/freezed_annotation.dart';

part 'invitation_redeemer_model.freezed.dart';
part 'invitation_redeemer_model.g.dart';

@freezed
abstract class InvitationRedeemerModel with _$InvitationRedeemerModel {
  const factory InvitationRedeemerModel({
    required String id,
    required String name,
    required String email,
  }) = _InvitationRedeemerModel;

  factory InvitationRedeemerModel.fromJson(Map<String, dynamic> json) =>
      _$InvitationRedeemerModelFromJson(json);
}
