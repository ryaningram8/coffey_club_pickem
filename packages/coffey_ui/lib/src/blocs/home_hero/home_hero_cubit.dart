import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../models/pick_summary_model.dart';
import '../../models/week_model.dart';
import '../../models/week_standing_model.dart';
import '../../models/week_summary_model.dart';
import '../../repositories/pick_repository.dart';
import '../../repositories/season_repository.dart';
import '../../repositories/standings_repository.dart';
import '../../repositories/week_repository.dart';

part 'home_hero_cubit.freezed.dart';
part 'home_hero_state.dart';

/// Picks which "hero" card the home screen shows — this-week status,
/// last-week recap, or a live-games snapshot — based on the current week's
/// status, or its absence (the gap between one week completing and the next
/// opening). A Cubit, not a Bloc, since there's only ever one operation
/// (load/reload) rather than distinct events. Unlike LiveResultsBloc this
/// does not run its own polling timer — it loads once per screen-open or
/// pull-to-refresh.
class HomeHeroCubit extends Cubit<HomeHeroState> {
  HomeHeroCubit({
    required WeekRepository weekRepository,
    required SeasonRepository seasonRepository,
    required StandingsRepository standingsRepository,
    required PickRepository pickRepository,
    required String currentUserId,
    required String seasonId,
  })  : _weekRepository = weekRepository,
        _seasonRepository = seasonRepository,
        _standingsRepository = standingsRepository,
        _pickRepository = pickRepository,
        _currentUserId = currentUserId,
        _seasonId = seasonId,
        super(const HomeHeroState.initial()) {
    load();
  }

  final WeekRepository _weekRepository;
  final SeasonRepository _seasonRepository;
  final StandingsRepository _standingsRepository;
  final PickRepository _pickRepository;
  final String _currentUserId;
  final String _seasonId;

  Future<void> load() async {
    emit(const HomeHeroState.loading());
    try {
      final week = await _weekRepository.getCurrentWeek(_seasonId);
      if (week == null) {
        emit(await _loadLastWeekRecap());
        return;
      }
      if (week.status == 'upcoming' || week.status == 'picks_open') {
        emit(await _loadThisWeek(week));
        return;
      }
      // 'locked' or 'in_progress' — picks are locked, games are underway.
      emit(await _loadLive(week));
    } catch (e) {
      emit(HomeHeroState.failure(e.toString()));
    }
  }

  Future<HomeHeroState> _loadThisWeek(WeekModel week) async {
    // Picks aren't submittable yet while 'upcoming', so skip the fetch and
    // let the card show deadline/pot only.
    int? picksMade;
    if (week.status == 'picks_open') {
      final picks = await _pickRepository.getPicks(week.id);
      picksMade = picks.length;
    }
    final lastCompleted = await _findMostRecentCompletedWeek();
    return HomeHeroState.thisWeek(
      week: week,
      picksMade: picksMade,
      totalGames: week.games.length,
      lastWeekLabel: lastCompleted?.label,
      lastWeekMessage: lastCompleted?.commissionerMessage,
    );
  }

  Future<HomeHeroState> _loadLive(WeekModel week) async {
    final summary = await _standingsRepository.getPicksSummary(week.id);
    final myEntry = _findEntry(summary, _currentUserId);
    final myCorrect = myEntry?.picks.where((p) => p.isCorrect == true).length ?? 0;
    final lastCompleted = await _findMostRecentCompletedWeek();
    return HomeHeroState.live(
      week: week,
      myCorrect: myCorrect,
      gamesFinal: week.games.where((g) => g.status == 'final').length,
      gamesInProgress: week.games.where((g) => g.status == 'in_progress').length,
      totalGames: week.games.length,
      lastWeekLabel: lastCompleted?.label,
      lastWeekMessage: lastCompleted?.commissionerMessage,
    );
  }

  Future<HomeHeroState> _loadLastWeekRecap() async {
    final lastWeek = await _findMostRecentCompletedWeek();
    if (lastWeek == null) return const HomeHeroState.empty();

    final standings = await _standingsRepository.getWeekStandings(lastWeek.id);
    return HomeHeroState.lastWeekRecap(
      week: lastWeek,
      myStanding: _findStanding(standings, _currentUserId),
    );
  }

  /// The most recently completed week in this pool, or null if none of its
  /// weeks are completed yet. Shared by the recap branch (which needs the
  /// whole week) and the this-week/live branches (which only need its
  /// commissioner message, so the roast stays visible through the
  /// following week, not just during the narrow gap the recap card
  /// occupies).
  Future<WeekSummaryModel?> _findMostRecentCompletedWeek() async {
    final weeks = await _seasonRepository.getWeeks(_seasonId);
    final completed = weeks.where((w) => w.status == 'completed').toList()
      ..sort((a, b) => b.weekNumber.compareTo(a.weekNumber));
    return completed.isEmpty ? null : completed.first;
  }

  PickSummaryEntryModel? _findEntry(List<PickSummaryEntryModel> entries, String userId) {
    for (final entry in entries) {
      if (entry.userId == userId) return entry;
    }
    return null;
  }

  WeekStandingModel? _findStanding(List<WeekStandingModel> standings, String userId) {
    for (final standing in standings) {
      if (standing.userId == userId) return standing;
    }
    return null;
  }
}
