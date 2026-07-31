part of 'payouts_bloc.dart';

@freezed
class PayoutsEvent with _$PayoutsEvent {
  const factory PayoutsEvent.started() = PayoutsStarted;
  const factory PayoutsEvent.paidToggled({
    required String userId,
    required bool isPaid,
  }) = PayoutsPaidToggled;
}
