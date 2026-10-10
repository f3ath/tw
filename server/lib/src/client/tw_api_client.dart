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

  Future<Resource> createVehicle({required String name, required DateTime manufactureDate}) async {
    final response = await _jsonApi.createNew(
      'vehicles',
      attributes: {'name': name, 'manufacture_date': _date(manufactureDate)},
      headers: _authHeaders(),
    );
    return response.resource;
  }

  Future<List<Resource>> listVehicles() async =>
      (await _jsonApi.fetchCollection('vehicles', headers: _authHeaders())).collection;

  Future<Resource> fetchVehicle(String id) async =>
      (await _jsonApi.fetchResource('vehicles', id, headers: _authHeaders())).resource;

  Future<Resource?> updateVehicle(String id, {String? name, DateTime? manufactureDate}) async {
    final attributes = <String, Object?>{};
    if (name != null) {
      attributes['name'] = name;
    }
    if (manufactureDate != null) {
      attributes['manufacture_date'] = _date(manufactureDate);
    }
    final response = await _jsonApi.updateResource(
      'vehicles',
      id,
      attributes: attributes,
      headers: _authHeaders(),
    );
    return response.resource;
  }

  Future<void> deleteVehicle(String id) async {
    await _jsonApi.deleteResource('vehicles', id, headers: _authHeaders());
  }

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

  String _date(DateTime date) => date.toIso8601String().split('T').first;
}
