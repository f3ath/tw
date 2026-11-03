import 'package:json_api/document.dart';

class Session(final String id, {final Uri? completionUri}) {
  static Session fromResource(Resource resource) {
    final redirect = resource.attributes['redirect'];
    final completionUri = redirect is String ? Uri.parse(redirect) : null;
    return Session(resource.id, completionUri: completionUri);
  }
}
