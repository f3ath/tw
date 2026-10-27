import 'package:http_interop/http_interop.dart';
import 'package:json_api/document.dart';
import 'package:json_api/routing.dart';
import 'package:json_api/server.dart';
import 'package:server/src/server/server_config.dart';
import 'package:server/src/auth/google_oauth.dart';
import 'package:server/src/auth/oauth_controller.dart';
import 'package:server/src/auth/request_ext.dart';
import 'package:server/src/auth/session_access_policy.dart';
import 'package:server/src/auth/sessions_controller.dart';
import 'package:server/src/auth/sessions_dao.dart';
import 'package:server/src/auth/simple_oauth.dart';
import 'package:server/src/auth/users_dao.dart';
import 'package:server/src/db/apply_migrations.dart';
import 'package:server/src/db/connection_from_config.dart';
import 'package:server/src/db/database.dart';
import 'package:server/src/http/logging_middleware.dart';
import 'package:server/src/http/responses.dart';
import 'package:server/src/http/routing_handler.dart';
import 'package:server/src/job/periodic_job.dart';
import 'package:server/src/log/log.dart';
import 'package:server/src/schedules/schedules_controller.dart';
import 'package:server/src/schedules/schedules_tdao.dart';
import 'package:server/src/services/services_controller.dart';
import 'package:server/src/services/services_tdao.dart';
import 'package:server/src/vehicles/vehicles_controller.dart';
import 'package:server/src/vehicles/vehicles_dao.dart';
import 'package:shared/api.dart';
import 'package:shared/time.dart';
import 'package:uuid/uuid.dart';

class Server(
  final ServerConfig _config, {
  SimpleOAuth? oauth,
  final Clock _clock = systemClock,
  Future<SystemConnection> Function(ServerConfig) systemConnectionFactory =
      SystemConnection.fromConfig,
  Future<TenantConnection> Function(ServerConfig) tenantConnectionFactory =
      TenantConnection.fromConfig,
  final Handler _defaultHandler = plainNotFound,
  final Log _log = const NoLog(),
}) {
  static const _googleOAuthCallbackPath = '/auth/google/callback';
  final _routes = <(RouteMatcher, Handler)>[];
  final _serverRoutes = <(RouteMatcher, Handler)>[];
  final _systemConnectionFactory = systemConnectionFactory;
  final _tenantConnectionFactory = tenantConnectionFactory;
  TenantConnection? _tenantConnection;
  PeriodicJob? _sessionCleanup;
  Future<void>? _starting;
  Future<void>? _stopping;
  final SimpleOAuth _oauth =
      oauth ??
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
        (_) async => Response(_isReady ? 200 : 500, Body.empty(), Headers()),
      ),
      ((rq) => rq.uri.path == '/k8s/liveness', (_) async => Response(200, Body.empty(), Headers())),
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
    if (_tenantConnection != null) return;
    final uriDesign = StandardUriDesign(_config.baseUri);
    final systemConnection = await _systemConnectionFactory(_config);
    try {
      await applyMigrations(systemConnection, _log);
    } finally {
      await systemConnection.close();
    }

    final tenantConnection = await _tenantConnectionFactory(_config);
    try {
      final db = Database(tenantConnection);

      final sessionsDAO = SessionsDAO(db, clock: _clock);
      final usersDAO = UsersDAO(db, clock: _clock);
      VehiclesDAO vehiclesDAOProvider(String ownerId) =>
          VehiclesDAO(ScopedDatabase(ownerId, tenantConnection), clock: _clock);
      SchedulesTDAO schedulesDAOProvider(String ownerId) =>
          SchedulesTDAO(ScopedDatabase(ownerId, tenantConnection), clock: _clock);
      ServicesTDAO servicesDAOProvider(String ownerId) =>
          ServicesTDAO(ScopedDatabase(ownerId, tenantConnection), clock: _clock);
      final googleOAuthController = OAuthController(_oauth, sessionsDAO, usersDAO);

      final controllers = <String, Controller>{
        ResourceType.sessions: SessionsController(_oauth, sessionsDAO, usersDAO, uriDesign.uri),
        ResourceType.vehicles: VehiclesController(
          vehiclesDAOProvider,
          schedulesDAOProvider,
          servicesDAOProvider,
          uriDesign.uri,
        ),
        ResourceType.schedules: SchedulesController(schedulesDAOProvider, uriDesign.uri),
        ResourceType.services: ServicesController(servicesDAOProvider, uriDesign.uri),
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
      final handleErrors = errorConverter(
        onError: (e, t) async {
          _log.error('ERROR', error: e, stackTrace: t);
          return internalServerError(
            OutboundErrorDocument([ErrorObject(title: 'Internal Server Error')]),
          );
        },
      );

      _serverRoutes.addAll([
        (
          (rq) => rq.uri.path.startsWith(_config.baseUri.path),
          handleErrors(corsMiddleware(jsonApiHandler)),
        ),
        ((rq) => rq.uri.path == _googleOAuthCallbackPath, googleOAuthController.callback),
      ]);
      _routes.addAll(_serverRoutes);
      _tenantConnection = tenantConnection;
      _sessionCleanup = PeriodicJob(
        () => sessionsDAO.deletePendingOlderThan(_config.pendingSessionMaxAge),
        interval: _config.sessionCleanupInterval,
        log: _log,
      )..start();
      _isReady = true;
    } catch (_) {
      await tenantConnection.close();
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
    for (final route in _serverRoutes) {
      _routes.remove(route);
    }
    _serverRoutes.clear();
    await _sessionCleanup?.stop();
    _sessionCleanup = null;
    final connection = _tenantConnection;
    _tenantConnection = null;
    await connection?.close();
  }

  Future<Response> call(Request rq) => _handler(rq);
}
