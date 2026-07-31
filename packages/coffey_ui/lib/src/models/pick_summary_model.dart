import 'package:freezed_annotation/freezed_annotation.dart';

part 'pick_summary_model.freezed.dart';
part 'pick_summary_model.g.dart';

@freezed
abstract class PickSummaryItemModel with _$PickSummaryItemModel {
  const factory PickSummaryItemModel({
    required String gameId,
    required String pickedTeamId,
    bool? isCorrect,
  }) = _PickSummaryItemModel;

  factory PickSummaryItemModel.fromJson(Map<String, dynamic> json) =>
      _$PickSummaryItemModelFromJson(json);
}

@freezed
abstract class PickSummaryEntryModel with _$PickSummaryEntryModel {
  const factory PickSummaryEntryModel({
    required String userId,
    required String userName,
    required List<PickSummaryItemModel> picks,
  }) = _PickSummaryEntryModel;

  factory PickSummaryEntryModel.fromJson(Map<String, dynamic> json) =>
      _$PickSummaryEntryModelFromJson(json);
}
