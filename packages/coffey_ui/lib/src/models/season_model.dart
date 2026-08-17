import 'package:freezed_annotation/freezed_annotation.dart';

part 'season_model.freezed.dart';
part 'season_model.g.dart';

@freezed
abstract class SeasonModel with _$SeasonModel {
  const factory SeasonModel({
    required String id,
    required String name,
    required int year,
    required String status,
    required String entryFee,
    required String payout1stPct,
    required String payout2ndPct,
    required String payout3rdPct,
    String? myRole,
  }) = _SeasonModel;

  factory SeasonModel.fromJson(Map<String, dynamic> json) => _$SeasonModelFromJson(json);
}
