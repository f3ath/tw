import 'dart:async';

import 'package:tw_app/app/auth/auth_exceptions.dart';
import 'package:tw_app/app/auth_service.dart';
import 'package:tw_app/data/auth/auth_api.dart';
import 'package:tw_app/data/auth/login_window.dart';
import 'package:tw_app/domain/user.dart';
import 'package:tw_app/time/clock.dart';

class BackendAuthService({
  required final AuthApi _authApi,
  required final LoginWindow Function() _newWindow,
  final Clock _clock = const Clock(),
}) implements AuthService {
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
