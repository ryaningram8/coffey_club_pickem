import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import '../../models/auth_response_model.dart';
import '../../models/auth_tokens_model.dart';

part 'auth_api.g.dart';

@RestApi()
abstract class AuthApi {
  factory AuthApi(Dio dio, {String baseUrl}) = _AuthApi;

  @POST('/auth/login')
  Future<AuthResponseModel> login(@Body() Map<String, dynamic> body);

  @POST('/auth/signup')
  Future<AuthResponseModel> signup(@Body() Map<String, dynamic> body);

  @POST('/auth/google')
  Future<AuthResponseModel> googleAuth(@Body() Map<String, dynamic> body);

  @POST('/auth/refresh')
  Future<AuthTokensModel> refresh(@Body() Map<String, dynamic> body);

  @POST('/auth/logout')
  Future<void> logout();
}
