import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

class UsersDAO(final Connection connection) {
  static const _uuid = Uuid();

  Future<UserRecord> createOrUpdate({required String email, required String name}) async {
    final id = _uuid.v4();
    final rows = await connection.execute(
      Sql.named('''
INSERT INTO users (id, email, name)
VALUES (@id:text, @email:text, @name:text)
ON CONFLICT (email) DO UPDATE SET name = excluded.name
RETURNING id, email, name
'''),
      parameters: {'id': id, 'email': email, 'name': name},
    );
    return _userRecord(rows.single.toColumnMap());
  }

  Future<UserRecord?> fetchByEmail(String email) async {
    final rows = await connection.execute(
      Sql.named('''
SELECT id, email, name
FROM users
WHERE email = @email:text
'''),
      parameters: {'email': email},
    );
    if (rows.isEmpty) {
      return null;
    }
    return _userRecord(rows.single.toColumnMap());
  }
}

UserRecord _userRecord(Map<String, dynamic> row) =>
    UserRecord(id: row['id'] as String, email: row['email'] as String, name: row['name'] as String);

class const UserRecord({
  required final String id,
  required final String email,
  required final String name,
});
