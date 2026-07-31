import 'package:freezed_annotation/freezed_annotation.dart';

part 'week_summary_model.freezed.dart';
part 'week_summary_model.g.dart';

/// Lightweight week shape used for list views (commissioner home screen) —
/// carries a game count instead of the full game list.
@freezed
abstract class WeekSummaryModel with _$WeekSummaryModel {
  const factory WeekSummaryModel({
    required String id,
    required String seasonId,
    required int weekNumber,
    required String label,
    required DateTime pickDeadline,
    required String status,
    required int gameCount,
  }) = _WeekSummaryModel;

  factory WeekSummaryModel.fromJson(Map<String, dynamic> json) =>
      _$WeekSummaryModelFromJson(json);
}
