import 'package:http_interop/http_interop.dart';
import 'package:test/test.dart';
import 'package:tw_server/src/auth/google/google_oauth.dart';
import 'package:tw_server/src/auth/google/google_oauth_controller.dart';

void main() {
  test('authorization URL preserves the caller supplied state', () {
    final GoogleOAuth oauth = GoogleOAuthClient(
      clientId: 'test-client-id',
      clientSecret: 'test-client-secret',
      redirectUri: 'http://localhost/auth/google/callback',
    );

    const state = 'caller state +/&=';
    expect(oauth.startAuthorization(state).queryParameters['state'], state);
  });

  test('authorization controller supplies a fresh state for each request', () async {
    final oauth = RecordingGoogleOAuth();
    final controller = GoogleOAuthController(oauth);
    final request = Request('get', Uri.parse('/auth'), Body(), Headers());

    expect((await controller.start(request)).statusCode, 302);
    expect((await controller.start(request)).statusCode, 302);
    expect(oauth.states, hasLength(2));
    expect(oauth.states.every((state) => state.isNotEmpty), isTrue);
    expect(oauth.states[0], isNot(oauth.states[1]));
  });
}

class RecordingGoogleOAuth implements GoogleOAuth {
  final states = <String>[];

  @override
  Uri startAuthorization(String state) {
    states.add(state);
    return Uri.https('accounts.google.com', '/o/oauth2/auth', {'state': state});
  }

  @override
  Future<GoogleOAuthSession?> finishAuthorization(Map<String, String> queryParameters) async => null;
}
