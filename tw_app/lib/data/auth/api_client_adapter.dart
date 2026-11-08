import 'package:tw_app/data/api_client.dart';
import 'package:tw_app/data/auth/auth_api.dart';
import 'package:tw_app/domain/user.dart';

class ApiClientAdapter(final ApiClient _client) implements AuthApi {
  @override
  Future<User?> getCurrentUser() async {
    final response = await _client.fetchRelatedResource('sessions', 'current', 'user');
    final resource = response.resource;
    if (resource == null) return null;
    return User(
      resource.id,
      name: resource.attributes['name'] as String? ?? '',
      email: resource.attributes['email'] as String? ?? '',
    );
  }

  @override
  Future<void> logout() async {
    try {
      await _client.deleteResource('sessions', 'current');
    } finally {
      _client.token = null;
    }
  }

  @override
  Future<Uri> startLogin() async {
    final response = await _client.createNew('sessions');
    final token = response.resource.attributes['token'];
    final redirect = response.resource.attributes['redirect'];
    if (token is! String) {
      throw InvalidResponse('Missing session token');
    }
    _client.token = token;
    if (redirect is! String) {
      throw InvalidResponse('Missing redirect URI');
    }
    final uri = Uri.tryParse(redirect);
    if (uri == null) {
      throw InvalidResponse('Invalid redirect URI');
    }
    return uri;
  }
}

class InvalidResponse(final String message) implements Exception;
