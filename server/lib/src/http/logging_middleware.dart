import 'package:http_interop_middleware/http_interop_middleware.dart';
import 'package:server/src/log/log.dart';

Middleware newLoggingMiddleware(Log log, String Function() newId) => middleware(
  onRequest: (rq) async {
    rq.context['request_id'] = newId();
    rq.context['request_time'] = DateTime.now();
    log.info('Rq:${rq.context['request_id']} ${rq.method} ${rq.uri.path}');
    return null;
  },
  onResponse: (rs, rq) async {
    final processingTime = DateTime.now().difference(rq.context['request_time']! as DateTime).inMilliseconds;
    log.info('Rs:${rq.context['request_id']} $processingTime ms ${rs.statusCode}');
    return null;
  },
  onError: (error, stackTrace, rq) async {
    log.error('Request ${rq.context['request_id']} failed!', error: error, stackTrace: stackTrace);
    return null;
  },
);
