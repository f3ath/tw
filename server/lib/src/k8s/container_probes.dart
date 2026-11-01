import 'package:http_interop/http_interop.dart';
import 'package:server/src/http/routing_handler.dart';

abstract interface class ContainerProbes() {
  bool isLive();

  bool isReady();

  bool isStarted();
}

Handler containerProbesMiddleware(ContainerProbes probes, Handler wrapped) => routingHandler([
  Route(
    matches: (rq) => rq.uri.path == '/k8s/is-started',
    handler: (_) async => Response(probes.isStarted() ? 200 : 500, Body.empty(), Headers()),
  ),
  Route(
    matches: (rq) => rq.uri.path == '/k8s/is-ready',
    handler: (_) async => Response(probes.isReady() ? 200 : 500, Body.empty(), Headers()),
  ),
  Route(
    matches: (rq) => rq.uri.path == '/k8s/is-live',
    handler: (_) async => Response(probes.isLive() ? 200 : 500, Body.empty(), Headers()),
  ),
], wrapped);
