import 'package:http_interop/http_interop.dart';

typedef RouteMatcher = bool Function(Request request);

class Route({required final RouteMatcher matches, required final Handler handler});

/// Dispatches to the first matching handler in list order.
Handler routingHandler(List<Route> routes, Handler defaultHandler) => (Request request) async {
  for (final route in routes) {
    if (route.matches(request)) return route.handler(request);
  }
  return defaultHandler(request);
};
