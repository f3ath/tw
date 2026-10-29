import 'dart:convert';

import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:server/src/auth/simple_oauth.dart';

class GoogleOAuthClient({
  required final String _clientId,
  required final String _clientSecret,
  required final String _redirectUri,
  final AuthEndpoints _authEndpoints = const GoogleAuthEndpoints(),
}) implements SimpleOAuth {
  static final _userInfoEndpoint = Uri.parse('https://openidconnect.googleapis.com/v1/userinfo');

  @override
  Uri startAuthorization(String nonce) => _authEndpoints.authorizationEndpoint.replace(
    queryParameters: {
      'client_id': _clientId,
      'redirect_uri': _redirectUri,
      'response_type': 'code',
      'scope': 'openid email profile',
      'state': nonce,
      'access_type': 'offline',
      'prompt': 'consent',
    },
  );

  @override
  Future<SimpleOAuthSession?> finishAuthorization(Map<String, String> queryParameters) async {
    final code = queryParameters['code'];
    final state = queryParameters['state'];
    if (code == null || state == null) {
      return null;
    }

    try {
      final userInfo = await _fetchUserInfo(code);
      final email = userInfo['email'] as String? ?? '';
      final name = userInfo['name'] as String? ?? '';

      return SimpleOAuthSession(email: email, name: name, nonce: state);
    } catch (e) {
      // TODO: log the error
      return null;
    }
  }

  Future<Map<String, Object?>> _fetchUserInfo(String code) => withDisposableHttp((client) async {
    final credentials = await obtainAccessCredentialsViaCodeExchange(
      client,
      ClientId(_clientId, _clientSecret),
      code,
      redirectUrl: _redirectUri,
      authEndpoints: _authEndpoints,
    );
    final authClient = authenticatedClient(client, credentials);
    try {
      return await _getJson(authClient, _userInfoEndpoint);
    } finally {
      authClient.close();
    }
  });
}

Future<Map<String, Object?>> _getJson(http.Client client, Uri uri) async {
  final response = await client.get(uri);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw StateError('Google OAuth request failed: ${response.statusCode} ${response.body}');
  }

  return jsonDecode(response.body) as Map<String, Object?>;
}

Future<T> withDisposableHttp<T>(Future<T> Function(http.Client) task) async {
  final client = http.Client();
  try {
    return await task(client);
  } finally {
    client.close();
  }
}
