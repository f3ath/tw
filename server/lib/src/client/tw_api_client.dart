import 'package:json_api/client.dart';
import 'package:json_api/document.dart';
import 'package:json_api/routing.dart';

class TwApiClient(UriDesign urlDesign, Client client) {
  final RoutingClient _jsonApi = RoutingClient(urlDesign, client);
  Resource? _session;

  Future<Resource?> createSession() async {
    final response = await _jsonApi.createNew('sessions');
    return _session = response.resource;
  }

  Future<List<Resource>> listSessions() async =>
      (await _jsonApi.fetchCollection('sessions', headers: _authHeaders())).collection;

  Future<void> deleteSession() async {
    final session = _session;
    if (session == null) {
      throw StateError('No session to delete');
    }
    await _jsonApi.deleteResource('sessions', session.id, headers: _authHeaders());
    _session = null;
  }

  Map<String, List<String>> _authHeaders() {
    final bearer = _session?.attributes['http_authorization_bearer'] as String?;
    if (bearer == null) {
      return const {};
    }
    return {
      'Authorization': ['Bearer $bearer'],
    };
  }
}
