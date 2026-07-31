part of 'weekly_standings_bloc.dart';

@freezed
class WeeklyStandingsEvent with _$WeeklyStandingsEvent {
  const factory WeeklyStandingsEvent.started() = WeeklyStandingsStarted;
  const factory WeeklyStandingsEvent.playerToggled(String userId) = WeeklyStandingsPlayerToggled;
}
