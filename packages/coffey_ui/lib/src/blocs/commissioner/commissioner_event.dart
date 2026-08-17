part of 'commissioner_bloc.dart';

@freezed
class CommissionerEvent with _$CommissionerEvent {
  const factory CommissionerEvent.started({required SeasonModel season}) = CommissionerStarted;

  const factory CommissionerEvent.weekCreateRequested({
    required int weekNumber,
    required String label,
    required DateTime pickDeadline,
  }) = CommissionerWeekCreateRequested;
}
