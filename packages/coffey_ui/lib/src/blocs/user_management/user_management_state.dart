part of 'user_management_bloc.dart';

@freezed
class UserManagementState with _$UserManagementState {
  const factory UserManagementState.initial() = UserManagementInitial;
  const factory UserManagementState.loading() = UserManagementLoading;

  const factory UserManagementState.loaded({
    required List<AdminUserModel> users,
    required List<SeasonModel> pools,

    /// Null = show every user, regardless of pool.
    String? poolFilter,

    /// `'$userId:$seasonId'` of the membership row currently being mutated.
    String? mutatingKey,
    String? errorMessage,
  }) = UserManagementLoaded;

  const factory UserManagementState.failure(String message) =
      UserManagementFailure;
}
