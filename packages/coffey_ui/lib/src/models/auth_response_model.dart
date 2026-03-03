import 'auth_tokens_model.dart';
import 'user_model.dart';

class AuthResponseModel {
  const AuthResponseModel({required this.tokens, required this.user});

  final AuthTokensModel tokens;
  final UserModel user;

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      tokens: AuthTokensModel.fromJson(json['tokens'] as Map<String, dynamic>),
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
