import 'package:freezed_annotation/freezed_annotation.dart';

part 'week_tiebreaker_model.freezed.dart';
part 'week_tiebreaker_model.g.dart';

@freezed
abstract class TiebreakerGameModel with _$TiebreakerGameModel {
  const factory TiebreakerGameModel({
    required String gameId,
    required String homeTeamName,
    required String awayTeamName,

    /// Null until both home and away scores are known for this game.
    int? actualCombinedScore,
  }) = _TiebreakerGameModel;

  factory TiebreakerGameModel.fromJson(Map<String, dynamic> json) =>
      _$TiebreakerGameModelFromJson(json);
}

@freezed
abstract class TiebreakerGuessModel with _$TiebreakerGuessModel {
  const factory TiebreakerGuessModel({required String gameId, int? guess}) =
      _TiebreakerGuessModel;

  factory TiebreakerGuessModel.fromJson(Map<String, dynamic> json) =>
      _$TiebreakerGuessModelFromJson(json);
}

@freezed
abstract class TiebreakerEntryModel with _$TiebreakerEntryModel {
  const factory TiebreakerEntryModel({
    required String userId,
    required String userName,
    required List<TiebreakerGuessModel> guesses,

    /// Sum of [guesses] across both tiebreaker games, or null if either is missing.
    int? guessTotal,

    /// |guessTotal - actual combined score|, or null until resolvable.
    int? distance,
  }) = _TiebreakerEntryModel;

  factory TiebreakerEntryModel.fromJson(Map<String, dynamic> json) =>
      _$TiebreakerEntryModelFromJson(json);
}

@freezed
abstract class WeekTiebreakerModel with _$WeekTiebreakerModel {
  const factory WeekTiebreakerModel({
    required List<TiebreakerGameModel> games,
    required List<TiebreakerEntryModel> entries,
  }) = _WeekTiebreakerModel;

  factory WeekTiebreakerModel.fromJson(Map<String, dynamic> json) =>
      _$WeekTiebreakerModelFromJson(json);
}
