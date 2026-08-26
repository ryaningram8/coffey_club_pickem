part of 'invitation_management_bloc.dart';

@freezed
class InvitationManagementEvent with _$InvitationManagementEvent {
  const factory InvitationManagementEvent.started() =
      InvitationManagementStarted;

  const factory InvitationManagementEvent.seasonSelected(String seasonId) =
      InvitationManagementSeasonSelected;

  const factory InvitationManagementEvent.codeGenerateRequested({
    String? email,
    int? count,
    DateTime? expiresAt,
    @Default(1) int? maxUses,
  }) = InvitationManagementCodeGenerateRequested;

  const factory InvitationManagementEvent.poolCreated({
    required String name,
    required int year,
  }) = InvitationManagementPoolCreated;
}
