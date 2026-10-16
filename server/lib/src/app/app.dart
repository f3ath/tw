import 'package:http_interop/http_interop.dart';
import 'package:http_interop_middleware/http_interop_middleware.dart';
import 'package:json_api/routing.dart';
import 'package:json_api/server.dart';
import 'package:tw_server/src/app/app_config.dart';
import 'package:tw_server/src/auth/google/google_oauth.dart';
import 'package:tw_server/src/auth/google/google_oauth_controller.dart';
import 'package:tw_server/src/auth/sessions_controller.dart';
import 'package:tw_server/src/auth/sessions_dao.dart';
import 'package:tw_server/src/auth/users_dao.dart';
import 'package:tw_server/src/db/apply_migrations.dart';
import 'package:tw_server/src/db/connection_from_config.dart';
import 'package:tw_server/src/http/context.dart';
import 'package:tw_server/src/http/responses.dart';
import 'package:tw_server/src/http/routing_handler.dart';
import 'package:tw_server/src/log/log.dart';
import 'package:tw_server/src/schedules/schedules_controller.dart';
import 'package:tw_server/src/schedules/schedules_dao.dart';
import 'package:tw_server/src/vehicles/vehicles_controller.dart';
import 'package:tw_server/src/vehicles/vehicles_dao.dart';

class App(
  final AppConfig _config, {
  GoogleOAuth? googleOAuth,
  final Handler _defaultHandler = _plainNotFound,
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
    final db = await connectionFromConfig(_config);
    await applyMigrations(db, _log);

    final sessionsDAO = SessionsDAO(db);
    final usersDAO = UsersDAO(db);
    final vehiclesDAO = VehiclesDAO(db);
    final schedulesDAO = SchedulesDAO(db);
    final googleOAuthController = GoogleOAuthController(_googleOAuth, sessionsDAO, usersDAO);

    final controllers = <String, Controller>{
      'sessions': SessionsController(_googleOAuth, sessionsDAO),
      'vehicles': VehiclesController(vehiclesDAO, schedulesDAO),
      'schedules': SchedulesController(schedulesDAO),
    };

    Future<SessionRecord?> getCallerUserId(Request rq) async {
      const prefix = 'Bearer ';
      final sessionId = rq.headers['Authorization']?.firstOrNull;
      if (sessionId != null) {
        final bearer = sessionId.startsWith(prefix) ? sessionId.substring(prefix.length) : null;
        if (bearer != null) {
          return await sessionsDAO.fetchBySessionKey(bearer);
        }
      }
      return null;
    }

    final UriDesign uriDesign = StandardUriDesign(_config.baseUri);

    Handler authenticationMiddleware(Handler inner) => (rq) async {
      final userId = (await getCallerUserId(rq))?.userId;
      if (userId != null) {
        Context(rq).userId = userId;
      }

      final target = uriDesign.target(rq.uri);
      if (userId != null ||
          (rq.method == 'post' && target is CollectionTarget && target.type == 'sessions')) {
        return await inner(rq);
      }
      return unauthorized();
    };

    final jsonApiHandler = authenticationMiddleware(
      router((type) => controllers[type], uriDesign.target),
    );

    _routes.addAll([
      ((rq) => rq.uri.path.startsWith(_config.baseUri.path), jsonApiHandler),
      ((rq) => rq.uri.path == _googleOAuthCallbackPath, googleOAuthController.callback),
    ]);
    _isReady = true;
  }

  Future<Response> call(Request rq) => _handler(rq);
}

Future<Response> _plainNotFound(Request rq) async => plain(404, '404 Not Found');
