import 'package:json_api/document.dart';
import 'package:tw_server/src/auth/sessions_dao.dart';
import 'package:tw_shared/api.dart';

class SessionResource(SessionRecord record) extends Resource {
  this : super(ResourceType.sessions, record.id) {
    attributes['key'] = record.sessionKey;
    relationships['user'] = ToOne(
      record.userId == null ? null : Identifier(ResourceType.users, record.userId!),
    );
  }
}
