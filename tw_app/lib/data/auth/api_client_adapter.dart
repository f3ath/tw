import 'package:shared/api.dart';
import 'package:tw_app/data/auth/auth_api.dart';

class ApiClientAdapter(final TwApiClient _client) implements AuthApi {
  @override
  Future<User?> getCurrentUser() => _client.fetchCurrentUser();

  @override
  Future<void> logout() => _client.deleteCurrentSession();

  @override
  Future<Uri> startLogin() async {
    final session = await _client.createSession();
    final redirect = session.completionUri;
    if (redirect == null) throw InvalidResponse('No redirect URI received');
    return redirect;
  }
}

class InvalidResponse(final String message) implements Exception;
