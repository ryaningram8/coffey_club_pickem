import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/season_model.dart';
import '../../repositories/invitation_repository.dart';
import '../../repositories/season_repository.dart';

part 'selected_pool_cubit.freezed.dart';
part 'selected_pool_state.dart';

/// Tracks which pool the header pool switcher is currently showing, and
/// persists the choice locally so it survives an app restart. A Cubit
/// rather than a BLoC — every operation (load, switch, join) is a direct
/// method call, not a stream of distinct event types. Provided at the app
/// root (see app.dart) so every screen — Home, Commissioner, Standings —
/// can read the same selection.
class SelectedPoolCubit extends Cubit<SelectedPoolState> {
  SelectedPoolCubit({
    required SeasonRepository seasonRepository,
    required InvitationRepository invitationRepository,
  })  : _seasonRepository = seasonRepository,
        _invitationRepository = invitationRepository,
        super(const SelectedPoolState.initial());

  final SeasonRepository _seasonRepository;
  final InvitationRepository _invitationRepository;
  static const _prefsKey = 'selected_pool_id';

  bool _isAdmin = false;

  /// Called once per authenticated session (see app.dart's AuthBloc
  /// listener) — admin sees every pool in the system via [getSeasons],
  /// everyone else only the ones they've actually joined via [getMySeasons].
  Future<void> load({required bool isAdmin}) async {
    _isAdmin = isAdmin;
    emit(const SelectedPoolState.loading());
    try {
      final pools = await _fetchPools();
      if (pools.isEmpty) {
        emit(const SelectedPoolState.noPools());
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final storedId = prefs.getString(_prefsKey);
      final selectedId = pools.any((p) => p.id == storedId) ? storedId! : pools.first.id;
      emit(SelectedPoolState.loaded(pools: pools, selectedPoolId: selectedId));
      await prefs.setString(_prefsKey, selectedId);
    } catch (e) {
      emit(SelectedPoolState.failure(e.toString()));
    }
  }

  /// Clean slate on logout, so a different user's next login doesn't
  /// briefly flash the previous session's pools.
  void reset() {
    _isAdmin = false;
    emit(const SelectedPoolState.initial());
  }

  Future<void> selectPool(String poolId) async {
    final current = state;
    if (current is! SelectedPoolLoaded) return;
    if (!current.pools.any((p) => p.id == poolId)) return;
    emit(current.copyWith(selectedPoolId: poolId));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, poolId);
  }

  /// Redeems an invite code for an additional pool and switches to it.
  /// Errors propagate to the caller (the "join a pool" dialog shows them
  /// inline) rather than blowing away the existing pool list/selection —
  /// on failure this reverts exactly to whatever state preceded the call.
  Future<void> joinPool(String code) async {
    final previous = state;
    if (previous is SelectedPoolLoaded) {
      emit(previous.copyWith(isJoiningPool: true));
    }
    try {
      final result = await _invitationRepository.redeemInvitation(code);
      final pools = await _fetchPools();
      emit(SelectedPoolState.loaded(pools: pools, selectedPoolId: result.seasonId));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, result.seasonId);
    } catch (e) {
      emit(previous);
      rethrow;
    }
  }

  Future<List<SeasonModel>> _fetchPools() {
    return _isAdmin ? _seasonRepository.getSeasons() : _seasonRepository.getMySeasons();
  }
}
