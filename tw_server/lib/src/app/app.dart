import 'package:http_interop/http_interop.dart';
import 'package:json_api/routing.dart';
import 'package:json_api/server.dart';
import 'package:postgres/postgres.dart';
import 'package:tw_server/src/app/app_config.dart';
import 'package:tw_server/src/auth/google/google_oauth.dart';
import 'package:tw_server/src/auth/google/google_oauth_controller.dart';
import 'package:tw_server/src/auth/request_ext.dart';
import 'package:tw_server/src/auth/session_access_policy.dart';
import 'package:tw_server/src/auth/sessions_controller.dart';
import 'package:tw_server/src/auth/sessions_dao.dart';
import 'package:tw_server/src/auth/users_dao.dart';
import 'package:tw_server/src/db/apply_migrations.dart';
import 'package:tw_server/src/db/connection_from_config.dart';
import 'package:tw_server/src/http/logging_middleware.dart';
import 'package:tw_server/src/http/responses.dart';
import 'package:tw_server/src/http/routing_handler.dart';
import 'package:tw_server/src/job/periodic_job.dart';
import 'package:tw_server/src/json_api/resource_type.dart';
import 'package:tw_server/src/log/log.dart';
import 'package:tw_server/src/schedules/schedules_controller.dart';
import 'package:tw_server/src/schedules/schedules_dao.dart';
import 'package:tw_server/src/time/clock.dart';
import 'package:tw_server/src/vehicles/vehicles_controller.dart';
import 'package:tw_server/src/vehicles/vehicles_dao.dart';
import 'package:uuid/uuid.dart';

class App(
  final AppConfig _config, {
  GoogleOAuth? googleOAuth,
  final Clock _clock = defaultClock,
  Future<Connection> Function(AppConfig) connectionFactory = connectionFromConfig,
  final Handler _defaultHandler = plainNotFound,
  final Log _log = const NoLog(),
}) {
  static const _googleOAuthCallbackPath = '/auth/google/callback';
  final _routes = <(RouteMatcher, Handler)>[];
  final _applicationRoutes = <(RouteMatcher, Handler)>[];
  final _connectionFactory = connectionFactory;
  Connection? _connection;
  PeriodicJob? _sessionCleanup;
  Future<void>? _starting;
  Future<void>? _stopping;
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

    final loggingMiddleware = newLoggingMiddleware(_log, const Uuid().v4);
    _handler = loggingMiddleware(routingHandler(_routes, _defaultHandler));
  }

  Future<void> start() {
    final stopping = _stopping;
    if (stopping != null) return stopping.then((_) => start());
    return _starting ??= _start().whenComplete(() {
      _starting = null;
    });
  }

  Future<void> _start() async {
    if (_connection != null) return;
    final uriDesign = StandardUriDesign(_config.baseUri);
    final db = await _connectionFactory(_config);
    try {
      await applyMigrations(db, _log);

      final sessionsDAO = SessionsDAO(db, clock: _clock);
      final usersDAO = UsersDAO(db, clock: _clock);
      final vehiclesDAO = VehiclesDAO(db, clock: _clock);
      final schedulesDAO = SchedulesDAO(db, clock: _clock);
      final googleOAuthController = GoogleOAuthController(_googleOAuth, sessionsDAO, usersDAO);

      final controllers = <String, Controller>{
        ResourceType.sessions: SessionsController(
          _googleOAuth,
          sessionsDAO,
          usersDAO,
          uriDesign.uri,
        ),
        ResourceType.vehicles: VehiclesController(vehiclesDAO, schedulesDAO, uriDesign.uri),
        ResourceType.schedules: SchedulesController(schedulesDAO, uriDesign.uri),
      };

      Future<SessionRecord?> getCallerSession(Request rq) async {
        final session = rq.sessionKey;
        if (session == null) return null;
        return sessionsDAO.fetchBySessionKey(session);
      }

      const sessionAccessPolicy = SessionAccessPolicy();

      final jsonApiHandler = router(
        getTarget: (httpRq) => uriDesign.target(httpRq.uri),
        getController: (_, target) => controllers[target.type],
        beforeDispatch: (jsonApiRq, _) async {
          final session = await getCallerSession(jsonApiRq.httpRequest);
          if (!sessionAccessPolicy.allows(jsonApiRq, session)) return unauthorized();

          final userId = session?.userId;
          if (userId != null) {
            jsonApiRq.httpRequest.userId = userId;
          }
          return null;
        },
      );
      final handleErrors = errorConverter();

      _applicationRoutes.addAll([
        (
          (rq) => rq.uri.path.startsWith(_config.baseUri.path),
          handleErrors(corsMiddleware(jsonApiHandler)),
        ),
        ((rq) => rq.uri.path == _googleOAuthCallbackPath, googleOAuthController.callback),
      ]);
      _routes.addAll(_applicationRoutes);
      _connection = db;
      _sessionCleanup = PeriodicJob(
        () => sessionsDAO.deletePendingOlderThan(_config.pendingSessionMaxAge),
        interval: _config.sessionCleanupInterval,
        log: _log,
      )..start();
      _isReady = true;
    } catch (_) {
      await db.close();
      rethrow;
    }
  }

  Future<void> stop() => _stopping ??= _stop().whenComplete(() {
    _stopping = null;
  });

  Future<void> _stop() async {
    _isReady = false;
    try {
      await _starting;
    } catch (_) {
      // Failed startup already closes its connection.
    }
    _isReady = false;
    for (final route in _applicationRoutes) {
      _routes.remove(route);
    }
    _applicationRoutes.clear();
    await _sessionCleanup?.stop();
    _sessionCleanup = null;
    final connection = _connection;
    _connection = null;
    await connection?.close();
  }

  Future<Response> call(Request rq) => _handler(rq);
}
