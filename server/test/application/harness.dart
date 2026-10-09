import 'package:http_interop/http_interop.dart';
import 'package:tw_server/src/application/application.dart';
import 'package:tw_server/src/auth/google/google_oauth.dart';

Future<Handler> testApplicationHandler(AppConfig config, GoogleOAuth googleOAuth) async {
  final app = App(config: config, googleOAuth: googleOAuth);
  await app.start();
  return app.call;
}

class TestGoogleOAuth() implements GoogleOAuth {
  final authorizationUri = Uri.parse('https://accounts.google.com/o/oauth2/auth?state=test-state');
  Map<String, String>? queryParameters;

  @override
  Uri startAuthorization() => authorizationUri;

  @override
  Future<GoogleOAuthSession?> finishAuthorization(Map<String, String> queryParameters) async {
    this.queryParameters = queryParameters;
    return GoogleOAuthSession(id: 'test-session-id', email: 'user@example.com', name: 'Test User');
  }
}
