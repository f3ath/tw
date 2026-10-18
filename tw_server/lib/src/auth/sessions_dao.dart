import 'dart:math';

import 'package:postgres/postgres.dart';
import 'package:tw_server/src/db/database.dart';
import 'package:tw_server/src/time/clock.dart';
import 'package:uuid/uuid.dart';

class SessionsDAO(final Database database, {Clock clock = systemClock}) {
  final _clock = clock;
  static const _uuid = Uuid();

  Future<SessionRecord> create() async {
    final session = SessionRecord(id: _uuid.v4(), nonce: _uuid.v4(), sessionKey: _newSessionKey());
    await database.execute(
      Sql.named('''
INSERT INTO sessions (id, session_key, nonce, user_id, created_at, updated_at)
VALUES (@id:text, @session_key:text, @nonce:text, @user_id:text, @now:timestamp, @now:timestamp)
'''),
      parameters: {...session.toMap(), 'now': _clock()},
    );
    return session;
  }

  Future<SessionRecord?> fetch(String id) async {
    final rows = await database.execute(
      Sql.named('''
SELECT id, session_key, nonce, user_id
FROM sessions
WHERE id = @id:text
'''),
      parameters: {'id': id},
    );
    if (rows.isEmpty) return null;
    return SessionRecord.fromMap(rows.single.toColumnMap());
  }

  Future<SessionRecord?> fetchBySessionKey(String sessionKey) async {
    final rows = await database.execute(
      Sql.named('''
SELECT id, session_key, nonce, user_id
FROM sessions
WHERE session_key = @session_key:text
'''),
      parameters: {'session_key': sessionKey},
    );
    if (rows.isEmpty) return null;
    return SessionRecord.fromMap(rows.single.toColumnMap());
  }

  Future<SessionRecord?> fetchByNonce(String nonce) async {
    final rows = await database.execute(
      Sql.named('''
SELECT id, session_key, nonce, user_id
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
SELECT id, session_key, nonce, user_id
FROM sessions
WHERE user_id = @user_id:text
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
SET user_id = @user_id:text, nonce = NULL, updated_at = @now:timestamp
WHERE nonce = @nonce:text
RETURNING id, session_key, nonce, user_id
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
WHERE id = @id:text AND user_id = @user_id:text
RETURNING id
'''),
      parameters: {'id': id, 'user_id': userId},
    );
    return rows.isNotEmpty;
  }
}

String _newSessionKey() {
  const charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  const length = 64;

  return String.fromCharCodes(
    List<int>.generate(length, (_) => charset.codeUnitAt(Random.secure().nextInt(charset.length))),
  );
}

class const SessionRecord({
  required final String id,
  required final String sessionKey,
  final String? nonce,
  final String? userId,
}) {
  static SessionRecord fromMap(Map<String, dynamic> map) => SessionRecord(
    id: map['id'] as String,
    sessionKey: map['session_key'] as String,
    nonce: map['nonce'] as String?,
    userId: map['user_id'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'session_key': sessionKey,
    'nonce': nonce,
    'user_id': userId,
  };
}
