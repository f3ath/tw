abstract interface class OAuth() {
  Uri startAuthentication(String nonce);

  Future<OAuthSession?> finishAuthentication(Map<String, String> queryParameters);
}

class OAuthSession({
  required final String email,
  required final String name,
  required final String nonce,
});
