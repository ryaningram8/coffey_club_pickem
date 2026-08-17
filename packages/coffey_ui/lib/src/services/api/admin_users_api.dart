import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import '../../models/admin_membership_model.dart';
import '../../models/admin_user_model.dart';

part 'admin_users_api.g.dart';

@RestApi()
abstract class AdminUsersApi {
  factory AdminUsersApi(Dio dio, {String baseUrl}) = _AdminUsersApi;

  @GET('/admin/users')
  Future<List<AdminUserModel>> getUsers();

  @PUT('/admin/users/{userId}/memberships/{seasonId}')
  Future<AdminMembershipModel> updateMembershipRole(
    @Path('userId') String userId,
    @Path('seasonId') String seasonId,
    @Body() Map<String, dynamic> body,
  );

  @DELETE('/admin/users/{userId}/memberships/{seasonId}')
  Future<void> removeMembership(@Path('userId') String userId, @Path('seasonId') String seasonId);
}
