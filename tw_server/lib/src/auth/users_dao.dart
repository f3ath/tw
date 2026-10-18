import 'package:postgres/postgres.dart';
import 'package:tw_server/src/db/database.dart';
import 'package:tw_shared/time.dart';
import 'package:uuid/uuid.dart';

class UsersDAO(final Database database, {Clock clock = systemClock}) {
  final _clock = clock;
  static const _uuid = Uuid();

  Future<UserRecord?> fetch(String id) async {
    final rows = await database.execute(
      Sql.named('''
SELECT id, email, name
FROM users
WHERE id = @id:uuid
'''),
      parameters: {'id': id},
    );
    if (rows.isEmpty) return null;
    return UserRecord.fromMap(rows.single.toColumnMap());
  }

  Future<UserRecord> createOrUpdate({required String email, required String name}) async {
    final user = UserRecord(id: _uuid.v4(), email: email, name: name);
    final rows = await database.execute(
      Sql.named('''
INSERT INTO users (id, email, name, created_at, updated_at)
VALUES (@id:uuid, @email:text, @name:text, @now:timestamp, @now:timestamp)
ON CONFLICT (email) DO UPDATE
SET name = EXCLUDED.name, updated_at = EXCLUDED.updated_at
RETURNING id, email, name
'''),
      parameters: {...user.toMap(), 'now': _clock()},
    );
    return UserRecord.fromMap(rows.single.toColumnMap());
  }

  Future<UserRecord?> fetchByEmail(String email) async {
    final rows = await database.execute(
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
    return UserRecord.fromMap(rows.single.toColumnMap());
  }
}

class const UserRecord({
  required final String id,
  required final String email,
  required final String name,
}) {
  static UserRecord fromMap(Map<String, dynamic> map) => UserRecord(
    id: map['id'] as String,
    email: map['email'] as String,
    name: map['name'] as String,
  );

  Map<String, dynamic> toMap() => {'id': id, 'email': email, 'name': name};
}
