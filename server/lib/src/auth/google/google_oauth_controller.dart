import 'package:http_interop/http_interop.dart';
import 'package:tw_server/src/auth/google/google_oauth.dart';
import 'package:tw_server/src/auth/sessions_dao.dart';
import 'package:tw_server/src/auth/users_dao.dart';
import 'package:tw_server/src/http/responses.dart';

class GoogleOAuthController(
  final GoogleOAuth googleOAuth,
  final SessionsDAO sessionsDAO,
  final UsersDAO usersDAO,
) {
  Future<Response> callback(Request request) async {
    final session = await googleOAuth.finishAuthorization(request.uri.queryParameters);
    if (session == null) {
      return plain(400, 'Invalid Google callback.');
    }
    final user = await usersDAO.createOrUpdate(email: session.email, name: session.name);
    final nonce = request.uri.queryParameters['state'];
    if (nonce == null) {
      return plain(400, 'Invalid Google callback.');
    }
    final linkedSession = await sessionsDAO.linkUserByNonce(nonce: nonce, userId: user.id);
    if (linkedSession == null) {
      return plain(400, 'Invalid Google callback.');
    }

    return plain(
      200,
      'Signed in with Google. Session: ${linkedSession.sessionKey}\nEmail: ${session.email}\nName: ${session.name}',
    );
  }
}
