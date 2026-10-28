import 'package:web/web.dart' as web;

import '../../domain/models.dart';
import 'oauth_window.dart';

OAuthWindow openOAuthWindow() {
  final popup = web.window.open('about:blank', '_blank');
  if (popup == null) {
    throw const AppFailure(
      FailureKind.connectivity,
      'Allow popups for this site and retry Google sign-in.',
    );
  }
  popup.opener = null;
  return _BrowserWindow(popup);
}

class _BrowserWindow(final web.Window popup) implements OAuthWindow {
  @override
  bool get isClosed => popup.closed;

  @override
  Future<void> navigate(Uri uri) async {
    popup.location.href = uri.toString();
  }

  @override
  void close() => popup.close();
}
