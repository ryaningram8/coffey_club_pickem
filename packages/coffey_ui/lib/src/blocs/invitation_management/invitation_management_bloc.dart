import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../models/invitation_model.dart';
import '../../models/season_model.dart';
import '../../repositories/invitation_repository.dart';
import '../../repositories/season_repository.dart';

part 'invitation_management_bloc.freezed.dart';
part 'invitation_management_event.dart';
part 'invitation_management_state.dart';

class InvitationManagementBloc
    extends Bloc<InvitationManagementEvent, InvitationManagementState> {
  InvitationManagementBloc({
    required SeasonRepository seasonRepository,
    required InvitationRepository invitationRepository,
  }) : _seasonRepository = seasonRepository,
       _invitationRepository = invitationRepository,
       super(const InvitationManagementState.initial()) {
    on<InvitationManagementStarted>(_onStarted);
    on<InvitationManagementSeasonSelected>(_onSeasonSelected);
    on<InvitationManagementCodeGenerateRequested>(_onCodeGenerateRequested);
  }

  final SeasonRepository _seasonRepository;
  final InvitationRepository _invitationRepository;

  Future<void> _onStarted(
    InvitationManagementStarted event,
    Emitter<InvitationManagementState> emit,
  ) async {
    emit(const InvitationManagementState.loading());
    try {
      final seasons = await _seasonRepository.getSeasons();
      if (seasons.isEmpty) {
        emit(const InvitationManagementState.noSeasons());
        return;
      }
      final invitations = await _invitationRepository.getInvitations(
        seasons.first.id,
      );
      emit(
        InvitationManagementState.loaded(
          seasons: seasons,
          selectedSeasonId: seasons.first.id,
          invitations: invitations,
        ),
      );
    } catch (e) {
      emit(InvitationManagementState.failure(e.toString()));
    }
  }

  Future<void> _onSeasonSelected(
    InvitationManagementSeasonSelected event,
    Emitter<InvitationManagementState> emit,
  ) async {
    final current = state;
    if (current is! InvitationManagementLoaded) return;
    try {
      final invitations = await _invitationRepository.getInvitations(
        event.seasonId,
      );
      emit(
        current.copyWith(
          selectedSeasonId: event.seasonId,
          invitations: invitations,
        ),
      );
    } catch (e) {
      emit(InvitationManagementState.failure(e.toString()));
    }
  }

  Future<void> _onCodeGenerateRequested(
    InvitationManagementCodeGenerateRequested event,
    Emitter<InvitationManagementState> emit,
  ) async {
    final current = state;
    if (current is! InvitationManagementLoaded) return;
    emit(current.copyWith(isGenerating: true));
    try {
      await _invitationRepository.createInvitations(
        seasonId: current.selectedSeasonId,
        email: event.email,
        count: event.count,
        expiresAt: event.expiresAt,
      );
      final invitations = await _invitationRepository.getInvitations(
        current.selectedSeasonId,
      );
      emit(current.copyWith(invitations: invitations, isGenerating: false));
    } catch (e) {
      emit(InvitationManagementState.failure(e.toString()));
    }
  }
}
