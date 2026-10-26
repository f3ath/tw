import 'package:server/src/auth/sessions_dao.dart';

class FakeSessionsDAO() implements SessionsDAO {
  final records = <String, SessionRecord>{};
  final fetchedIds = <String>[];

  @override
  Future<SessionRecord?> fetch(String id) async {
    fetchedIds.add(id);
    return records[id];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
