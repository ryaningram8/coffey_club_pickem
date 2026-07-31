import 'package:freezed_annotation/freezed_annotation.dart';

part 'season_standing_model.freezed.dart';
part 'season_standing_model.g.dart';

@freezed
abstract class SeasonStandingModel with _$SeasonStandingModel {
  const factory SeasonStandingModel({
    required String userId,
    required String userName,
    required int totalCorrect,
    required int weeksPlayed,
    required String totalPayout,
  }) = _SeasonStandingModel;

  factory SeasonStandingModel.fromJson(Map<String, dynamic> json) =>
      _$SeasonStandingModelFromJson(json);
}
