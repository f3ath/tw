import 'package:http_interop/http_interop.dart';
import 'package:http_interop_middleware/http_interop_middleware.dart';
import 'package:json_api/document.dart';
import 'package:json_api/server.dart';
import 'package:tw_server/src/log/log.dart';

/// Creates the standard API server middleware.
Middleware apiMiddleware({
  Future<bool> Function() k8sReadiness = _alwaysTrue,
  Future<bool> Function() k8sLiveness = _alwaysTrue,
  Log log = const NoLog(),
}) => [
  errorConverter(
    onError: (e, trace) async {
      log.error('Error: $e', error: e, stackTrace: trace);
      return internalServerError(OutboundErrorDocument([ErrorObject(title: 'Internal Server Error')]));
    },
    onUnmatchedTarget: (e) async => badRequest(
      OutboundErrorDocument([ErrorObject(status: '400', title: 'Unmatched target', detail: e.uri.toString())]),
    ),
  ),
  middleware(
    onRequest: (rq) async => switch (rq.uri.path) {
      '/k8s/readiness' => await k8sReadiness() ? _ok() : _ise(),
      '/k8s/liveness' => await k8sLiveness() ? _ok() : _ise(),
      _ => null,
    },
  ),
  corsMiddleware,
  middleware(
    onRequest: (rq) async {
      log.info('Rq: ${rq.method} ${rq.uri}');
      return null;
    },
    onResponse: (rs, rq) async {
      log.info('Rs: ${rs.statusCode}');
      return null;
    },
  ),
].reduce((a, b) => a.add(b));

Future<bool> _alwaysTrue() async => true;

Response _ok() => Response(200, Body(), Headers());

Response _ise() => Response(500, Body(), Headers());
