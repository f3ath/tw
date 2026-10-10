import 'package:http_interop/http_interop.dart';
import 'package:json_api/client.dart';
import 'package:json_api/document.dart';
import 'package:json_api/routing.dart';

class TwApiClient(UriDesign urlDesign, Handler handler) {
  this {
    _jsonApi = RoutingClient(urlDesign, Client(_authenticated(handler)));
  }

  late final RoutingClient _jsonApi;
  Resource? _session;

  Future<Resource?> createSession() async {
    final response = await _jsonApi.createNew('sessions');
    return _session = response.resource;
  }

  Future<List<Resource>> listSessions() async =>
      (await _jsonApi.fetchCollection('sessions')).collection;

  Future<Resource> createVehicle({required String name, required DateTime manufactureDate}) async {
    final response = await _jsonApi.createNew(
      'vehicles',
      attributes: {'name': name, 'manufacture_date': _date(manufactureDate)},
    );
    return response.resource;
  }

  Future<List<Resource>> listVehicles() async =>
      (await _jsonApi.fetchCollection('vehicles')).collection;

  Future<Resource> fetchVehicle(String id) async =>
      (await _jsonApi.fetchResource('vehicles', id)).resource;

  Future<Resource?> updateVehicle(String id, {String? name, DateTime? manufactureDate}) async {
    final attributes = <String, Object?>{};
    if (name != null) {
      attributes['name'] = name;
    }
    if (manufactureDate != null) {
      attributes['manufacture_date'] = _date(manufactureDate);
    }
    final response = await _jsonApi.updateResource('vehicles', id, attributes: attributes);
    return response.resource;
  }

  Future<void> deleteVehicle(String id) async {
    await _jsonApi.deleteResource('vehicles', id);
  }

  Future<void> deleteSession() async {
    final session = _session;
    if (session == null) {
      throw StateError('No session to delete');
    }
    await deleteSessionById(session.id);
  }

  Future<void> deleteSessionById(String id) async {
    await _jsonApi.deleteResource('sessions', id);
    if (_session?.id == id) {
      _session = null;
    }
  }

  Handler _authenticated(Handler inner) => (request) {
    final bearer = _session?.attributes['http_authorization_bearer'] as String?;
    if (bearer != null) {
      request.headers['Authorization'] = ['Bearer $bearer'];
    }
    return inner(request);
  };

  String _date(DateTime date) => date.toIso8601String().split('T').first;
}
