import 'package:app/data/auth/auth_api.dart';
import 'package:json_api/client.dart' show RequestFailure;
import 'package:shared/api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClientAdapter(
  final TwApiClient _client, {
  required final SharedPreferencesAsync _preferences,
  required Uri baseUri,
}) implements AuthApi {
  final String _tokenKey = 'session_token:$baseUri';
  Future<void>? _logout;

  @override
  Future<User?> restoreSession() async {
    _client.token = await _preferences.getString(_tokenKey);
    if (_client.token == null) return null;

    try {
      final user = await getCurrentUser();
      if (user != null) return user;
    } on RequestFailure catch (error) {
      final status = error.rawResponse.httpResponse.statusCode;
      if (status != 401 && status != 404) rethrow;
    }

    _client.token = null;
    await _preferences.remove(_tokenKey);
    return null;
  }

  @override
  Future<void> saveSession() => _preferences.setString(_tokenKey, _client.token!);

  @override
  Future<User?> getCurrentUser() => _client.fetchCurrentUser();

  @override
  Future<void> logout() => _logout ??= _deleteSession().whenComplete(() {
    _logout = null;
  });

  Future<void> _deleteSession() async {
    try {
      await _preferences.remove(_tokenKey);
    } finally {
      await _client.deleteCurrentSession();
    }
  }

  @override
  Future<Uri> startLogin() async {
    try {
      await _logout;
    } on Exception {
      // A failed revocation should not block a new login.
    }
    final session = await _client.createSession();
    final redirect = session.completionUri;
    if (redirect == null) throw InvalidResponse('No redirect URI received');
    return redirect;
  }
}

class InvalidResponse(final String message) implements Exception;
