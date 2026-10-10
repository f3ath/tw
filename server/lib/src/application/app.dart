import 'package:http_interop/http_interop.dart';
import 'package:http_interop_middleware/http_interop_middleware.dart';
import 'package:json_api/routing.dart';
import 'package:json_api/server.dart';
import 'package:postgres/postgres.dart';
import 'package:tw_server/src/application/app_config.dart';
import 'package:tw_server/src/auth/google/google_oauth.dart';
import 'package:tw_server/src/auth/google/google_oauth_controller.dart';
import 'package:tw_server/src/auth/sessions_controller.dart';
import 'package:tw_server/src/auth/sessions_dao.dart';
import 'package:tw_server/src/auth/users_dao.dart';
import 'package:tw_server/src/db/apply_migrations.dart';
import 'package:tw_server/src/http/responses.dart';
import 'package:tw_server/src/http/routing_handler.dart';
import 'package:tw_server/src/log/log.dart';

class App({
  required final AppConfig _config,
  GoogleOAuth? googleOAuth,
  final Handler _defaultHandler = plain404,
  final Log _log = const NoLog(),
}) {
  static const _googleOAuthCallbackPath = '/auth/google/callback';

  final _routes = <(RouteMatcher, Handler)>[];
  final GoogleOAuth _googleOAuth =
      googleOAuth ??
      GoogleOAuthClient(
        clientId: _config.googleOAuthClientId,
        clientSecret: _config.googleOAuthClientSecret,
        redirectUri: _config.baseUri.replace(path: _googleOAuthCallbackPath).toString(),
      );
  late final Handler _handler;
  var _isReady = false;

  this {
    _routes.addAll([
      (
        (rq) => rq.uri.path == '/k8s/readiness',
        (_) async => Response(_isReady ? 200 : 500, Body(), Headers()),
      ),
      ((rq) => rq.uri.path == '/k8s/liveness', (_) async => Response(200, Body(), Headers())),
    ]);
    final loggingMiddleware = middleware(
      onRequest: (rq) async {
        _log.debug('Rq: ${rq.method} ${rq.uri} ${rq.headers}');
        return null;
      },
      onResponse: (rs, rq) async {
        _log.debug('Rs: ${rs.statusCode} ${rs.headers}');
        return null;
      },
    );
    _handler = loggingMiddleware(routingHandler(_routes, _defaultHandler));
  }

  Future<void> start() async {
    final db = await Connection.open(
      Endpoint(
        host: _config.databaseHost,
        port: _config.databasePort,
        database: _config.databaseName,
        username: _config.databaseUsername,
        password: _config.databasePassword,
      ),
      settings: ConnectionSettings(sslMode: SslMode.disable),
    );
    await applyMigrations(db, _log);

    final sessionsDAO = SessionsDAO(db);
    final usersDAO = UsersDAO(db);
    final googleOAuthController = GoogleOAuthController(_googleOAuth, sessionsDAO, usersDAO);

    final controller = MappingController();
    controller.map['sessions'] = SessionsController(_googleOAuth, sessionsDAO);

    final jsonApiHandler = router(controller, StandardUriDesign(_config.baseUri).matchTarget);

    _routes.addAll([
      ((rq) => rq.uri.path.startsWith(_config.baseUri.path), jsonApiHandler),
      ((rq) => rq.uri.path == '/auth', googleOAuthController.start),
      ((rq) => rq.uri.path == _googleOAuthCallbackPath, googleOAuthController.callback),
    ]);
    _isReady = true;
  }

  Future<Response> call(Request rq) => _handler(rq);
}
