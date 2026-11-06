import 'package:tw_app/data/auth/login_window.dart';
import 'package:web/web.dart' as web;

LoginWindow openLoginWindow() {
  final popup = web.window.open('about:blank', '_blank');
  if (popup == null) {
    throw LoginWindowException('Could not open new window.');
  }
  return _LoginWindowWeb(popup);
}

class _LoginWindowWeb(final web.Window _window) implements LoginWindow {
  @override
  void close() {
    _window.close();
  }

  @override
  bool get isClosed => _window.closed;

  @override
  Future<void> navigate(Uri uri) async {
    _window.location.href = uri.toString();
  }
}
