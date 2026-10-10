import 'dart:convert';
import 'dart:math';

import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

abstract interface class GoogleOAuth() {
  Uri startAuthorization(String state);

  Future<GoogleOAuthSession?> finishAuthorization(Map<String, String> queryParameters);
}

class GoogleOAuthClient({
  required final String clientId,
  required final String clientSecret,
  required final String redirectUri,
  final AuthEndpoints authEndpoints = const GoogleAuthEndpoints(),
}) implements GoogleOAuth {
  static final _userInfoEndpoint = Uri.parse('https://openidconnect.googleapis.com/v1/userinfo');
  final _pendingGoogleStates = <String, DateTime>{};
  final _sessions = <String, Map<String, Object>>{};
  final _random = Random.secure();

  String _randomId() {
    final bytes = List<int>.generate(24, (_) => _random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  Uri _googleAuthorizationUrl(String state) => authEndpoints.authorizationEndpoint.replace(
    queryParameters: {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': 'openid email profile',
      'state': state,
      'access_type': 'offline',
      'prompt': 'consent',
    },
  );

  @override
  Uri startAuthorization(String state) {
    _pendingGoogleStates[state] = DateTime.now();
    return _googleAuthorizationUrl(state);
  }

  @override
  Future<GoogleOAuthSession?> finishAuthorization(Map<String, String> queryParameters) async {
    final code = queryParameters['code'];
    final state = queryParameters['state'];
    if (code == null || state == null) {
      return null;
    }

    if (_pendingGoogleStates.remove(state) == null) {
      return null;
    }

    final userInfo = await _fetchUserInfo(code);
    final email = userInfo['email'] as String? ?? '';
    final name = userInfo['name'] as String? ?? '';
    final sessionId = _randomId();
    _sessions[sessionId] = {
      'provider': 'google',
      'code': code,
      'state': state,
      'email': email,
      'name': name,
      'createdAt': DateTime.now().toIso8601String(),
    };

    return GoogleOAuthSession(id: sessionId, email: email, name: name);
  }

  Future<Map<String, Object?>> _fetchUserInfo(String code) async {
    final client = http.Client();
    try {
      final credentials = await obtainAccessCredentialsViaCodeExchange(
        client,
        ClientId(clientId, clientSecret),
        code,
        redirectUrl: redirectUri,
        authEndpoints: authEndpoints,
      );
      final authClient = authenticatedClient(client, credentials);
      try {
        return await _getJson(authClient, _userInfoEndpoint);
      } finally {
        authClient.close();
      }
    } finally {
      client.close();
    }
  }
}

class GoogleOAuthSession({
  required final String id,
  required final String email,
  required final String name,
}) {}

Future<Map<String, Object?>> _getJson(http.Client client, Uri uri) async {
  final response = await client.get(uri);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw StateError('Google OAuth request failed: ${response.statusCode} ${response.body}');
  }

  return jsonDecode(response.body) as Map<String, Object?>;
}
