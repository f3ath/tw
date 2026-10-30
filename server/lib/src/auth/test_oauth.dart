import 'package:server/src/auth/oauth.dart';

class TestOAuth() implements OAuth {
  @override
  Future<OAuthSession?> finishAuthorization(Map<String, String> queryParameters) async {
    final email = queryParameters['email'];
    final name = queryParameters['name'];
    final nonce = queryParameters['nonce'];
    if (email != null && name != null && nonce != null) {
      return OAuthSession(email: email, name: name, nonce: nonce);
    }
    return null;
  }

  @override
  Uri startAuthorization(String nonce) =>
      Uri.parse('https://example.com').replace(queryParameters: {'nonce': nonce});
}
