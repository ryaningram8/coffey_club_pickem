part of 'live_results_bloc.dart';

@freezed
class LiveResultsEvent with _$LiveResultsEvent {
  const factory LiveResultsEvent.started() = LiveResultsStarted;
  const factory LiveResultsEvent.refreshed() = LiveResultsRefreshed;
  const factory LiveResultsEvent.stopped() = LiveResultsStopped;
}
