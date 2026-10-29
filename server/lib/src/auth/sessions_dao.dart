import 'package:postgres/postgres.dart';
import 'package:server/src/db/database.dart';
import 'package:shared/time.dart';
import 'package:uuid/uuid.dart';

class SessionsDAO(final Database database, {Clock clock = systemClock}) {
  final _clock = clock;
  static const _uuid = Uuid();

  Future<SessionRecord> create({required String tokenHash}) async {
    final session = SessionRecord(id: _uuid.v4(), nonce: _uuid.v4(), tokenHash: tokenHash);
    await database.execute(
      Sql.named('''
INSERT INTO sessions (id, token_hash, nonce, user_id, created_at, updated_at)
VALUES (@id:uuid, @token_hash:text, @nonce:text, @user_id:uuid, @now:timestamp, @now:timestamp)
'''),
      parameters: {...session.toMap(), 'now': _clock()},
    );
    return session;
  }

  Future<SessionRecord?> fetch(String id) async {
    final rows = await database.execute(
      Sql.named('''
SELECT id, token_hash, nonce, user_id
FROM sessions
WHERE id = @id:uuid
'''),
      parameters: {'id': id},
    );
    if (rows.isEmpty) return null;
    return SessionRecord.fromMap(rows.single.toColumnMap());
  }

  Future<SessionRecord?> fetchByTokenHash(String tokenHash) async {
    final rows = await database.execute(
      Sql.named('''
SELECT id, token_hash, nonce, user_id
FROM sessions
WHERE token_hash = @token_hash:text
'''),
      parameters: {'token_hash': tokenHash},
    );
    if (rows.isEmpty) return null;
    return SessionRecord.fromMap(rows.single.toColumnMap());
  }

  Future<SessionRecord?> fetchByNonce(String nonce) async {
    final rows = await database.execute(
      Sql.named('''
SELECT id, token_hash, nonce, user_id
FROM sessions
WHERE nonce = @nonce:text
'''),
      parameters: {'nonce': nonce},
    );
    if (rows.isEmpty) return null;
    return SessionRecord.fromMap(rows.single.toColumnMap());
  }

  Future<List<SessionRecord>> fetchByUserId(String userId) async {
    final rows = await database.execute(
      Sql.named('''
SELECT id, token_hash, nonce, user_id
FROM sessions
WHERE user_id = @user_id:uuid
ORDER BY created_at
'''),
      parameters: {'user_id': userId},
    );
    return rows.map((row) => SessionRecord.fromMap(row.toColumnMap())).toList();
  }

  Future<SessionRecord?> linkUserByNonce({required String nonce, required String userId}) async {
    final rows = await database.execute(
      Sql.named('''
UPDATE sessions
SET user_id = @user_id:uuid, nonce = NULL, updated_at = @now:timestamp
WHERE nonce = @nonce:text
RETURNING id, token_hash, nonce, user_id
'''),
      parameters: {'nonce': nonce, 'user_id': userId, 'now': _clock()},
    );
    if (rows.isEmpty) return null;
    return SessionRecord.fromMap(rows.single.toColumnMap());
  }

  Future<void> deletePendingOlderThan(Duration maxAge) async {
    await database.execute(
      Sql.named('''
DELETE FROM sessions
WHERE user_id IS NULL
  AND created_at < @cutoff:timestamp
'''),
      parameters: {'cutoff': _clock().subtract(maxAge)},
    );
  }

  Future<bool> delete({required String id, required String userId}) async {
    final rows = await database.execute(
      Sql.named('''
DELETE FROM sessions
WHERE id = @id:uuid AND user_id = @user_id:uuid
RETURNING id
'''),
      parameters: {'id': id, 'user_id': userId},
    );
    return rows.isNotEmpty;
  }
}

class const SessionRecord({
  required final String id,
  required final String tokenHash,
  final String? nonce,
  final String? userId,
}) {
  static SessionRecord fromMap(Map<String, dynamic> map) => SessionRecord(
    id: map['id'] as String,
    tokenHash: map['token_hash'] as String,
    nonce: map['nonce'] as String?,
    userId: map['user_id'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'token_hash': tokenHash,
    'nonce': nonce,
    'user_id': userId,
  };
}
