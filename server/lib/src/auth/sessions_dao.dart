import 'dart:convert';
import 'dart:math';

import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

class SessionsDAO(final Connection connection) {
  static final _random = Random.secure();
  static const _uuid = Uuid();

  Future<SessionRecord> create() async {
    final session = SessionRecord(id: _uuid.v4(), sessionKey: _newSessionKey());
    await connection.execute(
      Sql.named('insert into sessions (id, session_key) values (@id:text, @session_key:text)'),
      parameters: {'id': session.id, 'session_key': session.sessionKey},
    );
    return session;
  }

  Future<SessionRecord?> fetch(String id) async {
    final rows = await connection.execute(
      Sql.named('select session_key from sessions where id = @id:text'),
      parameters: {'id': id},
    );
    if (rows.isEmpty) {
      return null;
    }
    return SessionRecord(id: id, sessionKey: rows.single[0] as String);
  }

  static String _newSessionKey() {
    final bytes = List<int>.generate(48, (_) => _random.nextInt(256));
    return base64Url.encode(bytes);
  }
}

class const SessionRecord({required final String id, required final String sessionKey}) {}
