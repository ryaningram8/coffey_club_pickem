import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../models/week_standing_model.dart';
import '../../repositories/payout_repository.dart';
import '../../repositories/standings_repository.dart';

part 'payouts_bloc.freezed.dart';
part 'payouts_event.dart';
part 'payouts_state.dart';

class PayoutsBloc extends Bloc<PayoutsEvent, PayoutsState> {
  PayoutsBloc({
    required StandingsRepository standingsRepository,
    required PayoutRepository payoutRepository,
    required String weekId,
  })  : _standingsRepository = standingsRepository,
        _payoutRepository = payoutRepository,
        _weekId = weekId,
        super(const PayoutsState.initial()) {
    on<PayoutsStarted>(_onStarted);
    on<PayoutsPaidToggled>(_onPaidToggled);
  }

  final StandingsRepository _standingsRepository;
  final PayoutRepository _payoutRepository;
  final String _weekId;

  Future<void> _onStarted(PayoutsStarted event, Emitter<PayoutsState> emit) async {
    emit(const PayoutsState.loading());
    try {
      final standings = await _standingsRepository.getWeekStandings(_weekId);
      emit(PayoutsState.loaded(standings: standings));
    } catch (e) {
      emit(PayoutsState.failure(e.toString()));
    }
  }

  Future<void> _onPaidToggled(
    PayoutsPaidToggled event,
    Emitter<PayoutsState> emit,
  ) async {
    final current = state;
    if (current is! PayoutsLoaded) return;
    emit(current.copyWith(updatingUserId: event.userId, errorMessage: null));
    try {
      await _payoutRepository.markPayout(_weekId, event.userId, event.isPaid);
      final standings = await _standingsRepository.getWeekStandings(_weekId);
      emit(PayoutsState.loaded(standings: standings));
    } catch (e) {
      emit(current.copyWith(updatingUserId: null, errorMessage: e.toString()));
    }
  }
}
