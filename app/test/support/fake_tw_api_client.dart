import 'package:json_api/document.dart';
import 'package:shared/api.dart';

class FakeTwApiClient() implements TwApiClient {
  final session = Resource(ResourceType.sessions, 'session-1')
    ..attributes['redirect'] = 'https://accounts.google.com/sign-in';
  var user = const User(id: 'user-1', name: 'Ada', email: 'ada@example.com');
  Future<Resource?> Function()? onCreateSession;
  Future<User?> Function()? onFetchUser;
  var pending = false;
  var failLogin = false;
  var failLogout = false;
  var createCount = 0;
  var deleteCount = 0;
  var fetchCount = 0;

  @override
  Future<Resource?> createSession() async {
    createCount++;
    if (failLogin) throw StateError('Login failed');
    return onCreateSession == null ? session : await onCreateSession!();
  }

  @override
  Future<User?> fetchCurrentUser() async {
    fetchCount++;
    if (onFetchUser != null) return onFetchUser!();
    return pending ? null : user;
  }

  @override
  Future<void> deleteSession() async {
    deleteCount++;
    if (failLogout) throw StateError('Logout failed');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
