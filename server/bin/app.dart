import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http_interop/http_interop.dart';
import 'package:json_api/routing.dart';
import 'package:json_api/server.dart';
import 'package:tw_server/src/http/api_middleware.dart';
import 'package:tw_server/src/io/process_signal.dart';
import 'package:tw_server/src/json_api/mapping_controller.dart';
import 'package:tw_server/src/json_api/server.dart';
import 'package:tw_server/src/log/log.dart';
import 'package:tw_server/src/log/std_err_log.dart';

const googleClientId = '933513547642-f4i961sf9ieq0ofcvq6cft61lf4umu7m.apps.googleusercontent.com';
const googleRedirectUri = 'http://localhost:8080/auth/google/callback';
const googleAuthEndpoint = 'https://accounts.google.com/o/oauth2/v2/auth';

final _pendingGoogleStates = <String, DateTime>{};
final _sessions = <String, Map<String, Object>>{};
final _random = Random.secure();

Future<void> main() async {
  final log = StdErrLog(minLevel: LogLevel.debug);
  log.info("Starting server...");
  const port = 8080;
  const baseUri = '/api/v0/';
  var isReady = false;

  final middleware = apiMiddleware(
    k8sReadiness: () async => isReady,
    k8sLiveness: () async => isReady,
    log: log,
  );

  final controller = MappingController();
  final handler = googleAuthMiddleware(
    middleware(router(controller, StandardUriDesign(Uri(path: baseUri)).matchTarget)),
  );
  final server = JsonApiServer(handler, port: port);
  await server.start();

  log.info('The server is listening at port $port.');
  isReady = true;
  log.info('The server is ready.');

  /// Graceful shutdown
  final signal = await firstProcessSignal([ProcessSignal.sigterm, ProcessSignal.sigint]);
  log.info('${signal.name.toUpperCase()} received. Shutting down...');
  isReady = false;
  log.info('Stopping the server...');
  await server.stop();
  log.info('Goodbye.');
}

Handler googleAuthMiddleware(Handler next) => (request) async {
  if (request.uri.path == '/auth') {
    if (request.method != 'get') return _text(405, 'Method Not Allowed');

    final state = _randomId();
    _pendingGoogleStates[state] = DateTime.now();
    return _redirect(_googleAuthorizationUrl(state));
  }

  if (request.uri.path != '/auth/google/callback') return next(request);

  final code = request.uri.queryParameters['code'];
  final state = request.uri.queryParameters['state'];
  if (code == null || state == null) {
    return _text(400, 'Missing Google callback code or state.');
  }

  if (_pendingGoogleStates.remove(state) == null) {
    return _text(400, 'Unknown Google callback state.');
  }

  final sessionId = _randomId();
  _sessions[sessionId] = {
    'provider': 'google',
    'code': code,
    'state': state,
    'createdAt': DateTime.now().toIso8601String(),
  };

  return _text(200, 'Signed in with Google. Session: $sessionId');
};

Uri _googleAuthorizationUrl(String state) => Uri.parse(googleAuthEndpoint).replace(
  queryParameters: {
    'client_id': googleClientId,
    'redirect_uri': googleRedirectUri,
    'response_type': 'code',
    'scope': 'openid email profile',
    'state': state,
    'access_type': 'offline',
    'prompt': 'consent',
  },
);

String _randomId() {
  final bytes = List<int>.generate(24, (_) => _random.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}

Response _text(int statusCode, String body) => Response(
  statusCode,
  Body.text(body, utf8),
  Headers()..addAll({
    'Content-Type': ['text/plain; charset=utf-8'],
  }),
);

Response _redirect(Uri location) => Response(
  302,
  Body(),
  Headers()..addAll({
    'Location': [location.toString()],
  }),
);
