import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import '../../models/invitation_model.dart';
import '../../models/invitation_redemption_model.dart';

part 'invitation_api.g.dart';

@RestApi()
abstract class InvitationApi {
  factory InvitationApi(Dio dio, {String baseUrl}) = _InvitationApi;

  @POST('/invitations')
  Future<List<InvitationModel>> createInvitations(@Body() Map<String, dynamic> body);

  @GET('/invitations')
  Future<List<InvitationModel>> getInvitations(@Query('seasonId') String seasonId);

  @POST('/invitations/{code}/redeem')
  Future<InvitationRedemptionModel> redeemInvitation(@Path('code') String code);
}
