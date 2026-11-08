import 'package:tw_app/domain/user.dart';

/// Outbound port to call server API
abstract interface class AuthApi {
  /// Calls the API and starts authentication. Returns the OAuth URI to finish login.
  Future<Uri> startLogin();

  Future<void> logout();

  Future<User?> getCurrentUser();
}
