import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import '../../models/pick_model.dart';

part 'pick_api.g.dart';

@RestApi()
abstract class PickApi {
  factory PickApi(Dio dio, {String baseUrl}) = _PickApi;

  @GET('/weeks/{id}/picks')
  Future<List<PickModel>> getPicks(@Path('id') String id);

  @POST('/weeks/{id}/picks')
  Future<List<PickModel>> submitPicks(@Path('id') String id, @Body() Map<String, dynamic> body);
}
