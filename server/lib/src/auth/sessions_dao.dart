import 'dart:convert';
import 'dart:math';

import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

class SessionsDAO(final Connection connection) {
  static final _random = Random.secure();
  static const _uuid = Uuid();

  Future<SessionRecord> create({String? sessionKey, String? userId}) async {
    final session = SessionRecord(
      id: _uuid.v4(),
      sessionKey: sessionKey ?? _newSessionKey(),
      userId: userId,
    );
    await connection.execute(
      Sql.named(
        'INSERT INTO sessions (id, session_key, user_id) VALUES (@id:text, @session_key:text, @user_id:text)',
      ),
      parameters: {'id': session.id, 'session_key': session.sessionKey, 'user_id': session.userId},
    );
    return session;
  }

  Future<SessionRecord?> fetch(String id) async {
    final rows = await connection.execute(
      Sql.named('SELECT session_key, user_id FROM sessions WHERE id = @id:text'),
      parameters: {'id': id},
    );
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.single.toColumnMap();
    return SessionRecord(
      id: id,
      sessionKey: row['session_key'] as String,
      userId: row['user_id'] as String?,
    );
  }

  Future<SessionRecord?> fetchBySessionKey(String sessionKey) async {
    final rows = await connection.execute(
      Sql.named(
        'SELECT id, session_key, user_id FROM sessions WHERE session_key = @session_key:text',
      ),
      parameters: {'session_key': sessionKey},
    );
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.single.toColumnMap();
    return _sessionRecord(row);
  }

  static String _newSessionKey() {
    final bytes = List<int>.generate(48, (_) => _random.nextInt(256));
    return base64Url.encode(bytes);
  }
}

SessionRecord _sessionRecord(Map<String, dynamic> row) => SessionRecord(
  id: row['id'] as String,
  sessionKey: row['session_key'] as String,
  userId: row['user_id'] as String?,
);

class const SessionRecord({
  required final String id,
  required final String sessionKey,
  final String? userId,
}) {}
