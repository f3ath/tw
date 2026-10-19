import 'package:http_interop/http_interop.dart';

extension RequestExt on Request {
  String? get sessionKey {
    final auth = headers['Authorization']?.firstOrNull;
    if (auth == null) return null;
    return auth.startsWith(_prefix) ? auth.substring(_prefix.length) : null;
  }

  set sessionKey(String id) {
    headers['Authorization'] = ['$_prefix$id'];
  }

  String get userId {
    if (context case {'user_id': String userId}) return userId;
    throw StateError('Unauthenticated');
  }

  set userId(String id) {
    context['user_id'] = id;
  }
}

const _prefix = 'Bearer ';
