import 'package:freezed_annotation/freezed_annotation.dart';
import 'game_model.dart';

part 'week_model.freezed.dart';
part 'week_model.g.dart';

@freezed
abstract class WeekModel with _$WeekModel {
  const factory WeekModel({
    required String id,
    required String seasonId,
    required int weekNumber,
    required String label,
    required DateTime pickDeadline,
    required String status,
    String? pot,
    @Default(<GameModel>[]) List<GameModel> games,
  }) = _WeekModel;

  factory WeekModel.fromJson(Map<String, dynamic> json) => _$WeekModelFromJson(json);
}
