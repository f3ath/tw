import 'package:json_api/document.dart';

class const User(final String id, {required final String name, required final String email});

extension ResourceToUserExt on Resource {
  User toUser() =>
      User(id, name: attributes['name'] as String, email: attributes['email'] as String);
}
