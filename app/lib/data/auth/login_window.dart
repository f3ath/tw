/// A browser window abstraction
abstract interface class LoginWindow {
  Future<void> navigate(Uri uri);

  void close();

  bool get isClosed;
}

class const LoginWindowException(final String message) implements Exception;
