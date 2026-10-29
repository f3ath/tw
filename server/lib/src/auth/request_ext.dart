import 'package:http_interop/http_interop.dart';

extension RequestExt on Request {
  String? get sessionToken {
    final auth = headers['Authorization']?.firstOrNull;
    if (auth == null || !auth.startsWith('Bearer ')) return null;
    return auth.substring('Bearer '.length);
  }

  String get userId {
    if (context case {'user_id': String userId}) return userId;
    throw StateError('Unauthenticated');
  }

  set userId(String id) {
    context['user_id'] = id;
  }
}
