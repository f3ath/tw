import 'dart:convert';
import 'dart:io';

import 'models.dart';

abstract interface class SessionStore() {
  Future<SessionInfo?> read();

  Future<void> write(SessionInfo session);

  Future<void> clear();
}

class FileSessionStore(final File file) implements SessionStore {
  factory defaultLocation() {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) {
      throw StateError('HOME is not set');
    }
    return FileSessionStore(File('$home/.twcli/session.json'));
  }

  @override
  Future<SessionInfo?> read() async {
    if (!await file.exists()) {
      return null;
    }
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return SessionInfo(
      id: json['id'] as String,
      bearer: json['bearer'] as String?,
      redirect: json['redirect'] == null ? null : Uri.parse(json['redirect'] as String),
    );
  }

  @override
  Future<void> write(SessionInfo session) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({
        'id': session.id,
        'bearer': session.bearer,
        'redirect': session.redirect?.toString(),
      }),
    );
  }

  @override
  Future<void> clear() async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}

class MemorySessionStore() implements SessionStore {
  SessionInfo? session;

  @override
  Future<SessionInfo?> read() async => session;

  @override
  Future<void> write(SessionInfo session) async {
    this.session = session;
  }

  @override
  Future<void> clear() async {
    session = null;
  }
}
