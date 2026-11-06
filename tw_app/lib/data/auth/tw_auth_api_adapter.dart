import 'package:shared/api.dart' as api;
import 'package:tw_app/data/auth/auth_service.dart';
import 'package:tw_app/data/auth/server_exception.dart';
import 'package:tw_app/domain/user.dart';

class TwAuthApiAdapter(final api.TwApiClient _client) implements AuthApiPort {
  @override
  Future<User?> getCurrentUser() async {
    final user = await _client.fetchCurrentUser();
    if (user == null) return null;
    return User(user.id, name: user.name ?? '', email: user.email ?? '');
  }

  @override
  Future<void> logout() => _client.deleteSession();

  @override
  Future<Uri> startLogin() async =>
      (await _client.createSession()).completionUri ?? (throw ServerException('No completion URI'));
}
