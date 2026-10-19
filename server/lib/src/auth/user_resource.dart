import 'package:json_api/document.dart';
import 'package:server/src/auth/users_dao.dart';
import 'package:shared/api.dart';

class UserResource(UserRecord record) extends Resource {
  this : super(ResourceType.users, record.id) {
    attributes.addAll({'email': record.email, 'name': record.name});
  }
}
