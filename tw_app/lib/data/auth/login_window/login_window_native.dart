import 'package:tw_app/data/auth/login_window.dart';
import 'package:url_launcher/url_launcher.dart';

LoginWindow openLoginWindow() => _LoginWindowNative();

class _LoginWindowNative() implements LoginWindow {
  @override
  void close() {
    // No way to control native browser
  }

  @override
  bool get isClosed => false;

  @override
  Future<void> navigate(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw const LoginWindowException('Could not open new window.');
    }
  }
}
