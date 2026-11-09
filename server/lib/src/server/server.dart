import 'package:http_interop/http_interop.dart';
import 'package:http_interop_middleware/http_interop_middleware.dart';
import 'package:json_api/document.dart';
import 'package:json_api/routing.dart';
import 'package:json_api/server.dart';
import 'package:server/src/auth/oauth/google_oauth.dart';
import 'package:server/src/auth/oauth/oauth.dart';
import 'package:server/src/auth/oauth/test_oauth.dart';
import 'package:server/src/auth/oauth_controller.dart';
import 'package:server/src/auth/request_ext.dart';
import 'package:server/src/auth/session_access_policy.dart';
import 'package:server/src/auth/sessions_controller.dart';
import 'package:server/src/auth/sessions_dao.dart';
import 'package:server/src/auth/token_hash.dart';
import 'package:server/src/db/apply_migrations.dart';
import 'package:server/src/db/connection_from_config.dart';
import 'package:server/src/db/database.dart';
import 'package:server/src/http/logging_middleware.dart';
import 'package:server/src/http/responses.dart';
import 'package:server/src/http/routing_handler.dart';
import 'package:server/src/job/periodic_job.dart';
import 'package:server/src/k8s/container_probes.dart';
import 'package:server/src/log/log.dart';
import 'package:server/src/schedules/schedules_controller.dart';
import 'package:server/src/schedules/schedules_dao.dart';
import 'package:server/src/server/server_config.dart';
import 'package:server/src/services/operations_controller.dart';
import 'package:server/src/services/operations_dao.dart';
import 'package:server/src/services/services_controller.dart';
import 'package:server/src/services/services_dao.dart';
import 'package:server/src/users/users_dao.dart';
import 'package:server/src/vehicles/vehicles_controller.dart';
import 'package:server/src/vehicles/vehicles_dao.dart';
import 'package:shared/api.dart';
import 'package:shared/time.dart';
import 'package:uuid/uuid.dart';

class Server(
  final ServerConfig _config, {
  final Clock _clock = systemClock,
  final Handler _catchAll = plainNotFound,
  final Log _log = const NoLog(),
}) implements ContainerProbes {
  static const _googleOAuthCallbackPath = '/auth/google/callback';
  final _routes = <Route>[];
  TenantConnection? _tenantConnection;
  PeriodicJob? _sessionCleanup;
  final OAuth _oauth = (switch (_config.instanceType) {
    'test' => TestOAuth(),
    _ => GoogleOAuthClient(
      clientId: _config.googleOAuthClientId,
      clientSecret: _config.googleOAuthClientSecret,
      redirectUri: _config.baseUri.replace(path: _googleOAuthCallbackPath).toString(),
    ),
  });
  late final _handler = newLoggingMiddleware(_log, () => const Uuid().v4().split('-').last)(
    routingHandler(_routes, _catchAll),
  );
  var _isReady = false;

  Future<void> start() async {
    await _applyMigrations();
    final tenantConnection = await TenantConnection.fromConfig(_config);
    _tenantConnection = tenantConnection;
    _setupControllers(tenantConnection);
    _isReady = true;
  }

  void _setupControllers(TenantConnection connection) {
    final db = Database(connection);

    final sessionsDAO = SessionsDAO(db, clock: _clock);
    final usersDAO = UsersDAO(db, clock: _clock);
    final googleOAuthController = OAuthController(_oauth, sessionsDAO, usersDAO);

    VehiclesDAO vehiclesDAOProvider(String ownerId) =>
        VehiclesDAO(ScopedDatabase(ownerId, connection), clock: _clock);
    SchedulesDAO schedulesDAOProvider(String ownerId) =>
        SchedulesDAO(ScopedDatabase(ownerId, connection), clock: _clock);
    ServicesDAO servicesDAOProvider(String ownerId) =>
        ServicesDAO(ScopedDatabase(ownerId, connection), clock: _clock);

    OperationsDAO operationsDAOProvider(String ownerId) =>
        OperationsDAO(ScopedDatabase(ownerId, connection), clock: _clock);

    final uriDesign = StandardUriDesign(_config.baseUri);

    final jsonApiControllers = <String, Controller>{
      ResourceType.sessions: SessionsController(_oauth, sessionsDAO, usersDAO, uriDesign.uri),
      ResourceType.vehicles: VehiclesController(
        vehiclesDAOProvider,
        schedulesDAOProvider,
        servicesDAOProvider,
        uriDesign.uri,
        clock: _clock,
      ),
      ResourceType.operations: OperationsController(operationsDAOProvider, uriDesign.uri),
      ResourceType.schedules: SchedulesController(schedulesDAOProvider, uriDesign.uri),
      ResourceType.services: ServicesController(
        servicesDAOProvider,
        operationsDAOProvider,
        uriDesign.uri,
        clock: _clock,
      ),
    };

    Future<SessionRecord?> getCallerSession(Request rq) async {
      final token = rq.sessionToken;
      if (token == null) return null;
      return sessionsDAO.fetchByTokenHash(tokenHash(token));
    }

    const sessionAccessPolicy = SessionAccessPolicy();

    final jsonApiHandler = router(
      getTarget: (rq) => uriDesign.target(rq.uri),
      getController: (_, target) => jsonApiControllers[target.type],
      beforeDispatch: (rq, _) async {
        final session = await getCallerSession(rq.httpRequest);
        if (!sessionAccessPolicy.allows(rq, session)) return unauthorized();

        final userId = session?.userId;
        if (userId != null) {
          rq.httpRequest.userId = userId;
        }
        return null;
      },
    );
    final errorHandlingMiddleware = errorConverter(
      onError: (e, t) async =>
          internalServerError(OutboundErrorDocument([ErrorObject(title: 'Internal Server Error')])),
    );

    final errorLoggingMiddleware = middleware(
      onError: (error, stackTrace, rq) async {
        _log.error(
          'Request ${rq.context['request_id']} failed!',
          error: error,
          stackTrace: stackTrace,
        );
        return null;
      },
    );

    _routes.addAll([
      Route(
        matches: (rq) => rq.uri.path.startsWith(_config.baseUri.path),
        handler: errorHandlingMiddleware(corsMiddleware(errorLoggingMiddleware(jsonApiHandler))),
      ),
      Route(
        matches: (rq) => rq.uri.path == _googleOAuthCallbackPath,
        handler: googleOAuthController.finishOAuth,
      ),
    ]);
    _sessionCleanup = PeriodicJob(
      () => sessionsDAO.deletePendingOlderThan(_config.pendingSessionMaxAge),
      interval: _config.sessionCleanupInterval,
      log: _log,
    )..start();
  }

  Future<void> _applyMigrations() async {
    final systemConnection = await SystemConnection.fromConfig(_config);
    try {
      await applyMigrations(systemConnection, _log);
    } finally {
      await systemConnection.close();
    }
  }

  Future<void> stop() async {
    _isReady = false;
    _routes.clear();
    await _sessionCleanup?.stop();
    await _tenantConnection?.close();
  }

  Future<Response> handler(Request rq) => _handler(rq);

  @override
  bool isReady() => _isReady;

  @override
  bool isLive() => true;

  @override
  bool isStarted() => true;
}
