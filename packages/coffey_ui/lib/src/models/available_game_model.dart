import 'package:freezed_annotation/freezed_annotation.dart';

part 'available_game_model.freezed.dart';
part 'available_game_model.g.dart';

/// Candidate team from `GET /games/available` — not yet a persisted [TeamModel].
@freezed
abstract class AvailableTeamModel with _$AvailableTeamModel {
  const factory AvailableTeamModel({
    required String espnId,
    required String name,
    required String abbreviation,
    String? logoUrl,
  }) = _AvailableTeamModel;

  factory AvailableTeamModel.fromJson(Map<String, dynamic> json) =>
      _$AvailableTeamModelFromJson(json);
}

/// Candidate game from `GET /games/available` — commissioner picks a subset
/// of these to publish via `POST /weeks/:id/games`.
@freezed
abstract class AvailableGameModel with _$AvailableGameModel {
  const factory AvailableGameModel({
    required String espnGameId,
    required String sport,
    required DateTime gameTime,
    required AvailableTeamModel homeTeam,
    required AvailableTeamModel awayTeam,
    double? spread,
    double? overUnder,
    @Default(false) bool isNeutralSite,
    String? venueName,
    String? venueCity,
    String? venueCountry,
  }) = _AvailableGameModel;

  factory AvailableGameModel.fromJson(Map<String, dynamic> json) =>
      _$AvailableGameModelFromJson(json);
}
