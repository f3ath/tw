import 'package:json_api/document.dart';

class const User({required final String id, final String? name, final String? email}) {
  static User fromResource(Resource resource) => User(
    id: resource.id,
    name: resource.attributes['name'] as String?,
    email: resource.attributes['email'] as String?,
  );

  String get displayName {
    for (final value in [name, email]) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return 'Signed in';
  }
}
