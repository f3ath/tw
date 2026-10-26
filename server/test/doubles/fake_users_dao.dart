import 'package:server/src/auth/users_dao.dart';

class FakeUsersDAO() implements UsersDAO {
  final records = <String, UserRecord>{};

  @override
  Future<UserRecord?> fetch(String id) async => records[id];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
