import 'package:url_launcher/url_launcher.dart';

import '../../domain/models.dart';
import 'oauth_window.dart';

OAuthWindow openOAuthWindow() => _ExternalBrowser();

class _ExternalBrowser() implements OAuthWindow {
  @override
  bool get isClosed => false;

  @override
  Future<void> navigate(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw const AppFailure(FailureKind.connectivity, 'Could not open Google sign-in. Retry.');
    }
  }

  @override
  void close() {}
}
