import 'package:freezed_annotation/freezed_annotation.dart';
import 'team_model.dart';

part 'game_model.freezed.dart';
part 'game_model.g.dart';

@freezed
abstract class GameModel with _$GameModel {
  const factory GameModel({
    required String id,
    required String weekId,
    required String sport,
    required String status,
    required DateTime gameTime,
    required TeamModel homeTeam,
    required TeamModel awayTeam,
    int? homeScore,
    int? awayScore,
    String? winnerTeamId,
    String? spread,
    String? overUnder,
    required int displayOrder,
    @Default(false) bool isNeutralSite,
    String? venueName,
    String? venueCity,
    String? venueCountry,
  }) = _GameModel;

  factory GameModel.fromJson(Map<String, dynamic> json) => _$GameModelFromJson(json);
}
