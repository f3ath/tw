import 'package:shared/model.dart';

/// Outbound port to call server API
abstract interface class AuthApi {
  Future<User?> restoreSession();

  Future<void> saveSession();

  /// Calls the API and starts authentication. Returns the OAuth URI to finish login.
  Future<Uri> startLogin();

  Future<void> logout();

  Future<User?> getCurrentUser();
}
