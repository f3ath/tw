abstract interface class SimpleOAuth() {
  Uri startAuthorization(String nonce);

  Future<SimpleOAuthSession?> finishAuthorization(Map<String, String> queryParameters);
}

class SimpleOAuthSession({
  required final String email,
  required final String name,
  required final String nonce,
});
