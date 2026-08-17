import 'package:freezed_annotation/freezed_annotation.dart';
import 'admin_membership_model.dart';

part 'admin_user_model.freezed.dart';
part 'admin_user_model.g.dart';

@freezed
abstract class AdminUserModel with _$AdminUserModel {
  const factory AdminUserModel({
    required String id,
    required String name,
    required String email,
    required bool isAdmin,
    required List<AdminMembershipModel> memberships,
  }) = _AdminUserModel;

  factory AdminUserModel.fromJson(Map<String, dynamic> json) => _$AdminUserModelFromJson(json);
}
