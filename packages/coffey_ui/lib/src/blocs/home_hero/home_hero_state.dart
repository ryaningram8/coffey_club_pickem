part of 'home_hero_cubit.dart';

@freezed
class HomeHeroState with _$HomeHeroState {
  const factory HomeHeroState.initial() = HomeHeroInitial;
  const factory HomeHeroState.loading() = HomeHeroLoading;

  const factory HomeHeroState.thisWeek({
    required WeekModel week,
    int? picksMade,
    required int totalGames,
    String? lastWeekLabel,
    String? lastWeekMessage,
  }) = HomeHeroThisWeek;

  const factory HomeHeroState.lastWeekRecap({
    required WeekSummaryModel week,
    WeekStandingModel? myStanding,
  }) = HomeHeroLastWeekRecap;

  const factory HomeHeroState.live({
    required WeekModel week,
    required int myCorrect,
    required int gamesFinal,
    required int gamesInProgress,
    required int totalGames,
    String? lastWeekLabel,
    String? lastWeekMessage,
  }) = HomeHeroLive;

  const factory HomeHeroState.empty() = HomeHeroEmpty;
  const factory HomeHeroState.failure(String message) = HomeHeroFailure;
}
