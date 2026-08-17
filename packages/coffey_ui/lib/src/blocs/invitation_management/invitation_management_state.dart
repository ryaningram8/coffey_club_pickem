part of 'invitation_management_bloc.dart';

@freezed
class InvitationManagementState with _$InvitationManagementState {
  const factory InvitationManagementState.initial() = InvitationManagementInitial;
  const factory InvitationManagementState.loading() = InvitationManagementLoading;

  /// No pools/seasons exist at all yet.
  const factory InvitationManagementState.noSeasons() = InvitationManagementNoSeasons;

  const factory InvitationManagementState.loaded({
    required List<SeasonModel> seasons,
    required String selectedSeasonId,
    required List<InvitationModel> invitations,
    @Default(false) bool isGenerating,
  }) = InvitationManagementLoaded;

  const factory InvitationManagementState.failure(String message) =
      InvitationManagementFailure;
}
