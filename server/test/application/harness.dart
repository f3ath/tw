import 'package:http_interop/http_interop.dart';
import 'package:tw_server/src/application/application.dart';
import 'package:tw_server/src/auth/google/google_oauth.dart';

Future<Handler> testApplicationHandler(AppConfig config, GoogleOAuth googleOAuth) async {
  final app = App(config: config, googleOAuth: googleOAuth);
  await app.start();
  return app.call;
}

class TestGoogleOAuth() implements GoogleOAuth {
  Uri? _authorizationUri;
  Uri get authorizationUri => _authorizationUri!;
  final states = <String>[];
  Map<String, String>? queryParameters;

  @override
  Uri startAuthorization(String state) {
    states.add(state);
    return _authorizationUri = Uri.https('accounts.google.com', '/o/oauth2/auth', {'state': state});
  }

  @override
  Future<GoogleOAuthSession?> finishAuthorization(Map<String, String> queryParameters) async {
    this.queryParameters = queryParameters;
    return GoogleOAuthSession(id: 'test-session-id', email: 'user@example.com', name: 'Test User');
  }
}
