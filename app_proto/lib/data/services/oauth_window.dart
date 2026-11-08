abstract interface class OAuthWindow() {
  bool get isClosed;
  Future<void> navigate(Uri uri);
  void close();
}
