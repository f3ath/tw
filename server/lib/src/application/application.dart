import 'dart:io';

import 'package:http_interop/http_interop.dart';
import 'package:http_interop_middleware/http_interop_middleware.dart';
import 'package:json_api/routing.dart';
import 'package:json_api/server.dart';
import 'package:migrant/migrant.dart';
import 'package:migrant_db_postgresql/migrant_db_postgresql.dart';
import 'package:migrant_source_fs/migrant_source_fs.dart';
import 'package:postgres/postgres.dart';
import 'package:tw_server/src/auth/google/google_oauth.dart';
import 'package:tw_server/src/auth/google/google_oauth_controller.dart';
import 'package:tw_server/src/auth/sessions_controller.dart';
import 'package:tw_server/src/db/logging_gateway_wrapper.dart';
import 'package:tw_server/src/http/responses.dart';
import 'package:tw_server/src/http/routing_handler.dart';
import 'package:tw_server/src/log/log.dart';

class AppConfig({
  required final Uri baseUri,
  required final String googleOAuthClientId,
  required final String googleOAuthClientSecret,
  required final String databaseHost,
  required final int databasePort,
  required final String databaseName,
  required final String databaseUsername,
  required final String databasePassword,
});

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
    final format = FileNameFormat(RegExp(r'\d{4}'));
    final directory = Directory('assets/db');
    final migrations = LocalFilesystem();
    _log.info('Reading all migrations from $directory:');
    final loaded = await migrations.load(
      directory,
      format,
      split: (sql) => sql.split('\n\n').where((it) => it.trim().isNotEmpty).toList(),
    );

    _log.info('Loaded $loaded migrations.');
    final c = await Connection.open(
      Endpoint(
        host: _config.databaseHost,
        port: _config.databasePort,
        database: _config.databaseName,
        username: _config.databaseUsername,
        password: _config.databasePassword,
      ),
      settings: ConnectionSettings(sslMode: SslMode.disable),
    );
    await Database(LoggingGatewayWrapper(PostgreSQLGateway(c))).upgrade(migrations);
    _log.info('Migrations applied.');

    final googleOAuthController = GoogleOAuthController(_googleOAuth);

    final controller = MappingController();
    controller.map['sessions'] = SessionsController(_googleOAuth);

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
