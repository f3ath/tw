import 'package:tw_app/domain/user.dart';

/// Authentication handling
abstract interface class AuthService {
  Future<User> login({Duration pollInterval, Duration pollTimeout});

  Future<void> logout();
}
