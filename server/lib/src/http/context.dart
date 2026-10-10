import 'package:http_interop/http_interop.dart';

/// Context reader/writer for a [Message].
class Context (final Message _msg) {
  static const String userIdKey = 'user_id';

  String get userId {
    if (_msg.context case {userIdKey: String userId}) return userId;
    throw StateError('Unauthenticated');
  }

  set userId(String id) {
    _msg.context[userIdKey] = id;
  }
}
