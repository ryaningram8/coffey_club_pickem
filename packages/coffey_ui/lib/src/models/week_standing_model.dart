import 'package:freezed_annotation/freezed_annotation.dart';

part 'week_standing_model.freezed.dart';
part 'week_standing_model.g.dart';

@freezed
abstract class WeekStandingModel with _$WeekStandingModel {
  const factory WeekStandingModel({
    required String userId,
    required String userName,
    String? venmoHandle,
    required int correctPicks,
    required int totalPicks,
    int? rank,
    String? payoutAmount,
    required bool isPaid,
  }) = _WeekStandingModel;

  factory WeekStandingModel.fromJson(Map<String, dynamic> json) =>
      _$WeekStandingModelFromJson(json);
}
