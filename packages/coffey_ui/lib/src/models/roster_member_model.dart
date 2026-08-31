import 'package:freezed_annotation/freezed_annotation.dart';

part 'roster_member_model.freezed.dart';
part 'roster_member_model.g.dart';

/// A season's member — used by the commissioner "enter picks for player"
/// player picker.
@freezed
abstract class RosterMemberModel with _$RosterMemberModel {
  const factory RosterMemberModel({
    required String userId,
    required String name,
    required String email,
    required String role,
  }) = _RosterMemberModel;

  factory RosterMemberModel.fromJson(Map<String, dynamic> json) =>
      _$RosterMemberModelFromJson(json);
}
