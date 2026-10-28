import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_interop/http_interop.dart';
import 'package:http_interop_http/http_interop_http.dart';
import 'package:json_api/client.dart' show RequestFailure;
import 'package:json_api/routing.dart';
import 'package:shared/api.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';
import 'oauth_browser.dart';
import 'oauth_window.dart';
import 'services.dart';

class ApiAuthService(
  final SettingsRepository settings,
  final LocalPersistenceService persistence, {
  final OAuthWindow Function() windowFactory = openOAuthWindow,
  final http.Client Function() httpClientFactory = http.Client.new,
  final Duration pollInterval = const Duration(seconds: 1),
  final Duration signInTimeout = const Duration(minutes: 5),
  final Duration requestTimeout = const Duration(seconds: 15),
}) {
  TwApiClient? _client;

  TwApiClient _clientFor(String address) =>
      TwApiClient(StandardUriDesign(Uri.parse(address)), (request) async {
        final transport = httpClientFactory();
        try {
          final response = await transport.sendInterop(request).timeout(requestTimeout);
          final body = await response.body.bytes
              .fold(BytesBuilder(copy: false), (buffer, chunk) => buffer..add(chunk))
              .timeout(requestTimeout);
          return Response(response.statusCode, Body.binary(body.takeBytes()), response.headers);
        } finally {
          transport.close();
        }
      });

  Future<T> _request<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AppFailure {
      rethrow;
    } on RequestFailure {
      throw const AppFailure(
        FailureKind.connectivity,
        'The server could not complete the request. Retry.',
      );
    } on http.ClientException {
      throw const AppFailure(
        FailureKind.connectivity,
        'Could not reach the server. Check the connection and retry.',
      );
    } on TimeoutException {
      throw const AppFailure(
        FailureKind.connectivity,
        'The server took too long to respond. Retry.',
      );
    } on FormatException {
      throw const AppFailure(
        FailureKind.connectivity,
        'The server returned an invalid response. Retry.',
      );
    }
  }

  Future<T> _storage<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (_) {
      throw const AppFailure(FailureKind.persistence, 'Could not read or save the session. Retry.');
    }
  }

  bool _expired(RequestFailure failure) =>
      [401, 404].contains(failure.rawResponse.httpResponse.statusCode);

  Future<String?> restore() => _request(() async {
    final saved = await _storage(() => persistence.read('session'));
    if (saved == null) return null;
    final address = await settings.load();
    final id = saved['id'];
    final key = saved['key'];
    if (id is! String || key is! String || saved['address'] != address) {
      await _storage(() => persistence.remove('session'));
      return null;
    }
    final client = _clientFor(address)..restoreSession(id: id, key: key);
    try {
      final user = await client.fetchCurrentUser();
      if (user != null) {
        _client = client;
        return user.email ?? user.displayName;
      }
    } on RequestFailure catch (failure) {
      if (!_expired(failure)) rethrow;
    }
    await _storage(() => persistence.remove('session'));
    _client = null;
    return null;
  });

  Future<String> signIn() => _request(() async {
    // Reserve the web popup while the sign-in click still has user activation.
    final window = windowFactory();
    try {
      final address = await settings.load();
      final client = _clientFor(address);
      final session = await client.createSession();
      final key = session?.attributes['key'];
      final redirect = session?.attributes['redirect'];
      final uri = redirect is String ? Uri.tryParse(redirect) : null;
      if (session == null ||
          key is! String ||
          uri == null ||
          !['http', 'https'].contains(uri.scheme) ||
          uri.host.isEmpty) {
        throw const AppFailure(
          FailureKind.connectivity,
          'The server returned an invalid sign-in response. Retry.',
        );
      }
      await window.navigate(uri);
      final elapsed = Stopwatch()..start();
      while (elapsed.elapsed < signInTimeout) {
        final user = await client.fetchCurrentUser();
        if (user != null) {
          await _storage(
            () => persistence.write('session', {'id': session.id, 'key': key, 'address': address}),
          );
          _client = client;
          return user.email ?? user.displayName;
        }
        if (window.isClosed) {
          throw const AppFailure(
            FailureKind.connectivity,
            'Sign-in was cancelled. Retry when ready.',
          );
        }
        await Future<void>.delayed(pollInterval);
      }
      throw const AppFailure(FailureKind.connectivity, 'Sign-in timed out. Please try again.');
    } finally {
      window.close();
    }
  });

  Future<void> signOut() => _request(() async {
    // Revoke at the session's original server even if Settings has since changed.
    final client = _client;
    if (client != null) {
      try {
        await client.deleteSession();
      } on RequestFailure catch (failure) {
        if (!_expired(failure)) rethrow;
      }
    }
    _client = null;
    await _storage(() => persistence.remove('session'));
  });
}
