import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import '../../models/available_game_model.dart';
import '../../models/game_model.dart';

part 'game_api.g.dart';

@RestApi()
abstract class GameApi {
  factory GameApi(Dio dio, {String baseUrl}) = _GameApi;

  @GET('/games/available')
  Future<List<AvailableGameModel>> getAvailableGames(@Query('sport') String? sport);

  @PUT('/games/{id}')
  Future<GameModel> updateGame(@Path('id') String id, @Body() Map<String, dynamic> body);

  @DELETE('/games/{id}')
  Future<void> deleteGame(@Path('id') String id);
}
