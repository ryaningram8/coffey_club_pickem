import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../models/pick_summary_model.dart';
import '../../models/week_model.dart';
import '../../models/week_tiebreaker_model.dart';
import '../../repositories/standings_repository.dart';
import '../../repositories/week_repository.dart';

part 'live_results_bloc.freezed.dart';
part 'live_results_event.dart';
part 'live_results_state.dart';

class LiveResultsBloc extends Bloc<LiveResultsEvent, LiveResultsState> {
  LiveResultsBloc({
    required WeekRepository weekRepository,
    required StandingsRepository standingsRepository,
    required String weekId,
  }) : _weekRepository = weekRepository,
       _standingsRepository = standingsRepository,
       _weekId = weekId,
       super(const LiveResultsState.initial()) {
    on<LiveResultsStarted>(_onStarted);
    on<LiveResultsRefreshed>(_onRefreshed);
    on<LiveResultsStopped>(_onStopped);
  }

  final WeekRepository _weekRepository;
  final StandingsRepository _standingsRepository;
  final String _weekId;
  Timer? _timer;

  Future<void> _onStarted(
    LiveResultsStarted event,
    Emitter<LiveResultsState> emit,
  ) async {
    emit(const LiveResultsState.loading());
    await _load(emit);
    _timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => add(const LiveResultsEvent.refreshed()),
    );
  }

  Future<void> _onRefreshed(
    LiveResultsRefreshed event,
    Emitter<LiveResultsState> emit,
  ) async {
    await _load(emit, silently: true);
  }

  void _onStopped(LiveResultsStopped event, Emitter<LiveResultsState> emit) {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _load(
    Emitter<LiveResultsState> emit, {
    bool silently = false,
  }) async {
    try {
      final week = await _weekRepository.getWeek(_weekId);
      final picksSummary = await _standingsRepository.getPicksSummary(_weekId);
      final tiebreaker = await _standingsRepository.getWeekTiebreaker(
        _weekId,
      );
      emit(
        LiveResultsState.loaded(
          week: week,
          picksSummary: picksSummary,
          tiebreaker: tiebreaker,
          lastUpdated: DateTime.now(),
        ),
      );
    } catch (e) {
      // A background refresh failing shouldn't blow away a previously
      // loaded screen — only surface failure on the initial load.
      if (!silently || state is! LiveResultsLoaded) {
        emit(LiveResultsState.failure(e.toString()));
      }
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
