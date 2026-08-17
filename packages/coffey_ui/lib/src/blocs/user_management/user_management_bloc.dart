import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../models/admin_user_model.dart';
import '../../models/season_model.dart';
import '../../repositories/admin_users_repository.dart';
import '../../repositories/season_repository.dart';

part 'user_management_bloc.freezed.dart';
part 'user_management_event.dart';
part 'user_management_state.dart';

class UserManagementBloc extends Bloc<UserManagementEvent, UserManagementState> {
  UserManagementBloc({
    required AdminUsersRepository adminUsersRepository,
    required SeasonRepository seasonRepository,
  })  : _adminUsersRepository = adminUsersRepository,
        _seasonRepository = seasonRepository,
        super(const UserManagementState.initial()) {
    on<UserManagementStarted>(_onStarted);
    on<UserManagementPoolFilterChanged>(_onPoolFilterChanged);
    on<UserManagementRoleChangeRequested>(_onRoleChangeRequested);
    on<UserManagementRemoveRequested>(_onRemoveRequested);
  }

  final AdminUsersRepository _adminUsersRepository;
  final SeasonRepository _seasonRepository;

  Future<void> _onStarted(
    UserManagementStarted event,
    Emitter<UserManagementState> emit,
  ) async {
    emit(const UserManagementState.loading());
    try {
      final users = await _adminUsersRepository.getUsers();
      final pools = await _seasonRepository.getSeasons();
      emit(UserManagementState.loaded(users: users, pools: pools));
    } catch (e) {
      emit(UserManagementState.failure(e.toString()));
    }
  }

  void _onPoolFilterChanged(
    UserManagementPoolFilterChanged event,
    Emitter<UserManagementState> emit,
  ) {
    final current = state;
    if (current is! UserManagementLoaded) return;
    emit(current.copyWith(poolFilter: event.seasonId));
  }

  Future<void> _onRoleChangeRequested(
    UserManagementRoleChangeRequested event,
    Emitter<UserManagementState> emit,
  ) async {
    final current = state;
    if (current is! UserManagementLoaded) return;
    emit(current.copyWith(mutatingKey: '${event.userId}:${event.seasonId}', errorMessage: null));
    try {
      await _adminUsersRepository.updateMembershipRole(
        userId: event.userId,
        seasonId: event.seasonId,
        role: event.role,
      );
      final users = await _adminUsersRepository.getUsers();
      emit(current.copyWith(users: users, mutatingKey: null));
    } catch (e) {
      emit(current.copyWith(mutatingKey: null, errorMessage: e.toString()));
    }
  }

  Future<void> _onRemoveRequested(
    UserManagementRemoveRequested event,
    Emitter<UserManagementState> emit,
  ) async {
    final current = state;
    if (current is! UserManagementLoaded) return;
    emit(current.copyWith(mutatingKey: '${event.userId}:${event.seasonId}', errorMessage: null));
    try {
      await _adminUsersRepository.removeMembership(
        userId: event.userId,
        seasonId: event.seasonId,
      );
      final users = await _adminUsersRepository.getUsers();
      emit(current.copyWith(users: users, mutatingKey: null));
    } catch (e) {
      emit(current.copyWith(mutatingKey: null, errorMessage: e.toString()));
    }
  }
}
