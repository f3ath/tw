import 'dart:async';

import 'package:tw_app/app/tw_app.dart';
import 'package:tw_app/application/auth/auth_exceptions.dart';
import 'package:tw_app/domain/user.dart';
import 'package:tw_app/time/clock.dart';

class AuthService({
  required final AuthApiPort _authApi,
  required final LoginWindow Function() _newWindow,
  final Clock _clock = const Clock(),
}) implements AuthServicePort {
  @override
  Future<User> login({
    Duration pollInterval = const Duration(seconds: 2),
    Duration pollTimeout = const Duration(seconds: 30),
  }) async {
    final window = _newWindow();
    try {
      final uri = await _authApi.startLogin();
      await window.navigate(uri);
      final deadline = _clock.now().add(pollTimeout);
      while (_clock.now().isBefore(deadline)) {
        if (window.isClosed) throw UserCancelledException('User cancelled');
        final user = await _authApi.getCurrentUser();
        if (user != null) return user;
        await _clock.delayed<void>(pollInterval);
      }
      throw TimeoutException('Login never finished');
    } finally {
      if (!window.isClosed) {
        window.close();
      }
    }
  }

  @override
  Future<void> logout() => _authApi.logout();
}

class const LoginWindowException(final String message) implements Exception;

/// Outbound port to call server API
abstract interface class AuthApiPort {
  /// Calls the API and starts authentication. Returns the OAuth URI to finish login.
  Future<Uri> startLogin();

  Future<void> logout();

  Future<User?> getCurrentUser();
}

/// A browser window abstraction
abstract interface class LoginWindow {
  Future<void> navigate(Uri uri);

  void close();

  bool get isClosed;
}
