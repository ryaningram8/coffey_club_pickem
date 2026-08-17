part of 'user_management_bloc.dart';

@freezed
class UserManagementEvent with _$UserManagementEvent {
  const factory UserManagementEvent.started() = UserManagementStarted;

  const factory UserManagementEvent.poolFilterChanged(String? seasonId) =
      UserManagementPoolFilterChanged;

  const factory UserManagementEvent.roleChangeRequested({
    required String userId,
    required String seasonId,
    required String role,
  }) = UserManagementRoleChangeRequested;

  const factory UserManagementEvent.removeRequested({
    required String userId,
    required String seasonId,
  }) = UserManagementRemoveRequested;
}
