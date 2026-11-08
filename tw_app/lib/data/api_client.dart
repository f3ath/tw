import 'package:json_api/client.dart';

class ApiClient(super.uriForTarget, super.client) extends RoutingClient {
  String? token;

  @override
  Future<Response> send(Uri uri, Request request) {
    final t = token;
    if (t != null) {
      request.headers['Authorization'] = ['Bearer $token'];
    }
    return super.send(uri, request);
  }
}
