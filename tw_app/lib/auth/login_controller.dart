import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tw_app/auth/login_state.dart';
import 'package:tw_shared/api.dart';
import 'package:tw_shared/time.dart';

class LoginController({
  required final TwApiClient _client,
  required final Future<bool> Function(Uri) _openAuthorization,
  final Duration _pollInterval = const Duration(seconds: 2),
  final Duration _signInTimeout = const Duration(minutes: 3),
  final Clock _clock = systemClock,
}) extends ChangeNotifier {
  LoginState _state = const SignedOut();
  String? _error;
  Timer? _pollTimer;
  Completer<void>? _pollWait;
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
      final uri = Uri.tryParse(session?.attributes['redirect'] as String? ?? '');
      if (uri == null || !uri.hasAuthority || !const ['http', 'https'].contains(uri.scheme)) {
        throw StateError('Missing authorization URL');
      }
      _transition(AwaitingAuthorization(uri));
      if (!_isActive(attempt)) return;
      final opened = await _tryOpenAuthorization(uri);
      if (!_isActive(attempt)) return;
      if (!opened) {
        _reportError('Select Open sign-in to continue in your browser.');
      }

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
        await _waitForPoll(remaining < _pollInterval ? remaining : _pollInterval);
      }
      if (_isActive(attempt)) {
        _transition(const SignedOut(), error: 'Sign-in timed out. Please try again.');
      }
    } catch (_) {
      if (_isActive(attempt)) {
        _transition(const SignedOut(), error: 'Could not sign in. Please try again.');
      }
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
    _cancelPollWait();
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

  Future<void> _waitForPoll(Duration duration) {
    final wait = Completer<void>();
    _pollWait = wait;
    _pollTimer = Timer(duration, () {
      _pollTimer = null;
      _pollWait = null;
      wait.complete();
    });
    return wait.future;
  }

  void _cancelPollWait() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollWait?.complete();
    _pollWait = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _attempt++;
    _cancelPollWait();
    super.dispose();
  }
}
