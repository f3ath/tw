import 'package:http_interop/http_interop.dart';
typedef RouteMatcher = bool Function(Request request);
/// Dispatches to the first matching handler in list order.
Handler routingHandler(
  List<(RouteMatcher, Handler)> routes,
  Handler defaultHandler,
) => (Request request) async {
  for (final (matcher, handler) in routes) {
    if (matcher(request)) return handler(request);
  }
  return defaultHandler(request);
};
