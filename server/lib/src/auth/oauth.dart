abstract interface class OAuth() {
  Uri startAuthorization(String nonce);

  Future<OAuthSession?> finishAuthorization(Map<String, String> queryParameters);
}

class OAuthSession({
  required final String email,
  required final String name,
  required final String nonce,
});
