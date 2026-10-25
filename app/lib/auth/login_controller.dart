import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:app/auth/login_state.dart';
import 'package:shared/api.dart';
import 'package:shared/time.dart';

class LoginController({
  required final TwApiClient _client,
  required final Future<bool> Function(Uri) _openAuthorization,
  final Duration _pollInterval = const Duration(seconds: 2),
  final Duration _signInTimeout = const Duration(minutes: 3),
  final Clock _clock = systemClock,
}) extends ChangeNotifier {
  LoginState _state = const SignedOut();
  String? _error;
  final _pollDelay = _CancellableDelay();
  Future<void>? _pendingLogin;
  var _attempt = 0;
  var _disposed = false;

  LoginState get state => _state;

  String? takeError() {
    final error = _error;
    _error = null;
    return error;
  }

  Future<void> login() async {
    if (_disposed || _state is! SignedOut) return;
    final attempt = ++_attempt;
    _transition(const SigningIn());
    final operation = _login(attempt, _pendingLogin);
    _pendingLogin = operation;
    await operation;
    if (identical(_pendingLogin, operation)) _pendingLogin = null;
  }

  Future<void> _login(int attempt, Future<void>? previous) async {
    try {
      // The client stores the active session. Let a cancelled request finish
      // before starting another that could otherwise be overwritten by it.
      if (previous != null) await previous;
      if (!_isActive(attempt)) return;
      final session = await _client.createSession();
      if (!_isActive(attempt)) return;
      final uri = _authorizationUri(session?.attributes['redirect'] as String?);
      _transition(AwaitingAuthorization(uri));
      if (!_isActive(attempt)) return;
      final opened = await _tryOpenAuthorization(uri);
      if (!_isActive(attempt)) return;
      if (!opened) {
        _reportError('Select Open sign-in to continue in your browser.');
      }

      await _pollForUser(attempt);
    } catch (_) {
      if (_isActive(attempt)) {
        _transition(const SignedOut(), error: 'Could not sign in. Please try again.');
      }
    }
  }

  static Uri _authorizationUri(String? redirect) {
    final uri = Uri.tryParse(redirect ?? '');
    if (uri == null || !uri.hasAuthority || !const ['http', 'https'].contains(uri.scheme)) {
      throw StateError('Missing authorization URL');
    }
    return uri;
  }

  Future<void> _pollForUser(int attempt) async {
    final deadline = _clock().add(_signInTimeout);
    while (_isActive(attempt) && _clock().isBefore(deadline)) {
      final user = await _client.fetchCurrentUser();
      if (!_isActive(attempt)) return;
      if (user != null) {
        _transition(SignedIn(user.displayName));
        return;
      }
      final remaining = deadline.difference(_clock());
      if (remaining <= Duration.zero) break;
      await _pollDelay.wait(remaining < _pollInterval ? remaining : _pollInterval);
    }
    if (_isActive(attempt)) {
      _transition(const SignedOut(), error: 'Sign-in timed out. Please try again.');
    }
  }

  Future<void> openAuthorization() async {
    final state = _state;
    if (_disposed || state is! AwaitingAuthorization) return;
    final attempt = _attempt;
    final opened = await _tryOpenAuthorization(state.uri);
    if (!opened && _isActive(attempt) && _state is AwaitingAuthorization) {
      _reportError('Could not open the sign-in page.');
    }
  }

  Future<bool> _tryOpenAuthorization(Uri uri) async {
    try {
      return await _openAuthorization(uri);
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    final state = _state;
    if (_disposed || state is! SignedIn) return;
    final attempt = ++_attempt;
    _transition(SigningOut(state.userName));
    try {
      await _client.deleteSession();
      if (_isActive(attempt)) _transition(const SignedOut());
    } catch (_) {
      if (_isActive(attempt)) {
        _transition(state, error: 'Could not log out. Please try again.');
      }
    }
  }

  void cancelLogin() {
    if (_disposed || (_state is! SigningIn && _state is! AwaitingAuthorization)) {
      return;
    }
    _attempt++;
    _pollDelay.cancel();
    _transition(const SignedOut());
  }

  bool _isActive(int attempt) => !_disposed && attempt == _attempt;

  void _transition(LoginState state, {String? error}) {
    _state = state;
    _error = error;
    notifyListeners();
  }

  void _reportError(String error) {
    _error = error;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _attempt++;
    _pollDelay.cancel();
    super.dispose();
  }
}

class _CancellableDelay() {
  Timer? _timer;
  Completer<void>? _pending;

  Future<void> wait(Duration duration) {
    final wait = Completer<void>();
    _pending = wait;
    _timer = Timer(duration, cancel);
    return wait.future;
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _pending?.complete();
    _pending = null;
  }
}
