import 'dart:async';

import 'package:app/app/auth/auth_exceptions.dart';
import 'package:app/app/auth_service.dart';
import 'package:app/data/auth/auth_api.dart';
import 'package:app/data/auth/login_window.dart';
import 'package:shared/model.dart';
import 'package:shared/time.dart';

class BackendAuthService({
  required final AuthApi _authApi,
  required final LoginWindow Function() _newWindow,
  final Delayed<void> _delayed = Future.delayed,
  final Now _now = DateTime.now,
}) implements AuthService {
  @override
  Future<User?> restoreSession() => _authApi.restoreSession();

  @override
  Future<User> login({
    Duration pollInterval = const Duration(seconds: 2),
    Duration pollTimeout = const Duration(seconds: 30),
  }) async {
    final window = _newWindow();
    try {
      final uri = await _authApi.startLogin();
      await window.navigate(uri);
      final deadline = _now().add(pollTimeout);
      while (_now().isBefore(deadline)) {
        if (window.isClosed) throw UserCancelledException('User cancelled');
        final user = await _authApi.getCurrentUser();
        if (user != null) {
          await _authApi.saveSession();
          return user;
        }
        await _delayed(pollInterval);
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
