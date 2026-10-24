import 'dart:convert';

import 'package:http_interop/http_interop.dart';
import 'package:server/src/auth/google/google_oauth.dart';
import 'package:server/src/auth/sessions_dao.dart';
import 'package:server/src/auth/users_dao.dart';
import 'package:server/src/http/responses.dart';

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

    return Response(
      200,
      Body.text(_successPage(session.name)),
      Headers()..addAll({
        'Content-Type': ['text/html; charset=utf-8'],
      }),
    );
  }
}

String _successPage(String name) =>
    '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Signed in</title>
</head>
<body>
  <p>Thank you, ${const HtmlEscape(HtmlEscapeMode.element).convert(name)}, you may close this page.</p>
  <p id="close-status">Closing automatically in <span id="countdown">5</span> seconds.</p>
  <script>
    let remaining = 5;
    const countdown = document.getElementById('countdown');
    const timer = window.setInterval(() => {
      remaining -= 1;
      countdown.textContent = remaining;
      if (remaining === 0) {
        window.clearInterval(timer);
        document.getElementById('close-status').textContent = 'You may close this page.';
        window.close();
      }
    }, 1000);
  </script>
</body>
</html>
''';
