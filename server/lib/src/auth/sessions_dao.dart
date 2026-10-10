import 'dart:math';

import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

class SessionsDAO(final Connection connection) {
  static final _random = Random.secure();
  static const _uuid = Uuid();
  static const _sessionKeyChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

  Future<SessionRecord> create({String? nonce, String? sessionKey, String? userId}) async {
    final session = SessionRecord(
      id: _uuid.v4(),
      nonce: nonce ?? _uuid.v4(),
      sessionKey: sessionKey ?? _newSessionKey(),
      userId: userId,
    );
    await connection.execute(
      Sql.named(
        'INSERT INTO sessions (id, session_key, nonce, user_id) VALUES (@id:text, @session_key:text, @nonce:text, @user_id:text)',
      ),
      parameters: {
        'id': session.id,
        'session_key': session.sessionKey,
        'nonce': session.nonce,
        'user_id': session.userId,
      },
    );
    return session;
  }

  Future<SessionRecord?> fetch(String id) async {
    final rows = await connection.execute(
      Sql.named('SELECT id, session_key, nonce, user_id FROM sessions WHERE id = @id:text'),
      parameters: {'id': id},
    );
    if (rows.isEmpty) {
      return null;
    }
    return _sessionRecord(rows.single.toColumnMap());
  }

  Future<SessionRecord?> fetchBySessionKey(String sessionKey) async {
    final rows = await connection.execute(
      Sql.named(
        'SELECT id, session_key, nonce, user_id FROM sessions WHERE session_key = @session_key:text',
      ),
      parameters: {'session_key': sessionKey},
    );
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.single.toColumnMap();
    return _sessionRecord(row);
  }

  Future<SessionRecord?> fetchByNonce(String nonce) async {
    final rows = await connection.execute(
      Sql.named('SELECT id, session_key, nonce, user_id FROM sessions WHERE nonce = @nonce:text'),
      parameters: {'nonce': nonce},
    );
    if (rows.isEmpty) {
      return null;
    }
    return _sessionRecord(rows.single.toColumnMap());
  }

  Future<List<SessionRecord>> fetchByUserId(String userId) async {
    final rows = await connection.execute(
      Sql.named(
        'SELECT id, session_key, nonce, user_id FROM sessions WHERE user_id = @user_id:text ORDER BY created_at',
      ),
      parameters: {'user_id': userId},
    );
    return rows.map((row) => _sessionRecord(row.toColumnMap())).toList();
  }

  Future<SessionRecord?> linkUserByNonce({required String nonce, required String userId}) async {
    final rows = await connection.execute(
      Sql.named(
        'UPDATE sessions SET user_id = @user_id:text, nonce = NULL WHERE nonce = @nonce:text RETURNING id, session_key, nonce, user_id',
      ),
      parameters: {'nonce': nonce, 'user_id': userId},
    );
    if (rows.isEmpty) {
      return null;
    }
    return _sessionRecord(rows.single.toColumnMap());
  }

  static String _newSessionKey() => String.fromCharCodes(
    List<int>.generate(
      64,
      (_) => _sessionKeyChars.codeUnitAt(_random.nextInt(_sessionKeyChars.length)),
    ),
  );
}

SessionRecord _sessionRecord(Map<String, dynamic> row) => SessionRecord(
  id: row['id'] as String,
  nonce: row['nonce'] as String?,
  sessionKey: row['session_key'] as String,
  userId: row['user_id'] as String?,
);

class const SessionRecord({
  required final String id,
  required final String sessionKey,
  final String? nonce,
  final String? userId,
}) {}
