import 'package:freezed_annotation/freezed_annotation.dart';

part 'pick_model.freezed.dart';
part 'pick_model.g.dart';

@freezed
abstract class PickModel with _$PickModel {
  const factory PickModel({
    required String gameId,
    required String pickedTeamId,
    int? tiebreakerGuess,
  }) = _PickModel;

  factory PickModel.fromJson(Map<String, dynamic> json) => _$PickModelFromJson(json);
}
