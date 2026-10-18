import 'package:json_api/document.dart';
import 'package:tw_server/src/auth/users_dao.dart';
import 'package:tw_server/src/json_api/resource_type.dart';

class UserResource(UserRecord record) extends Resource {
  this : super(ResourceType.users, record.id) {
    attributes.addAll({'email': record.email, 'name': record.name});
  }
}
