import 'package:freezed_annotation/freezed_annotation.dart';

part 'admin_membership_model.freezed.dart';
part 'admin_membership_model.g.dart';

@freezed
abstract class AdminMembershipModel with _$AdminMembershipModel {
  const factory AdminMembershipModel({
    required String seasonId,
    required String seasonName,
    required String role,
    required DateTime joinedAt,
  }) = _AdminMembershipModel;

  factory AdminMembershipModel.fromJson(Map<String, dynamic> json) =>
      _$AdminMembershipModelFromJson(json);
}
