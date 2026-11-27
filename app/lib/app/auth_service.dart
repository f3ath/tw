import 'package:shared/model.dart';

/// Authentication handling
abstract interface class AuthService {
  Future<User?> restoreSession();

  Future<User> login({Duration pollInterval, Duration pollTimeout});

  Future<void> logout();
}
