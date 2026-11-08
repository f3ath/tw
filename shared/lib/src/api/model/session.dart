import 'package:json_api/document.dart';

class Session(final String id, {final Uri? completionUri});

extension ResourceToSessionExt on Resource {
  Session toSession() {
    final redirect = attributes['redirect'];
    return Session(id, completionUri: redirect is String ? Uri.parse(redirect) : null);
  }
}
