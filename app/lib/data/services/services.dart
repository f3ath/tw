import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models.dart';

abstract interface class LocalPersistenceService() {
  Future<Map<String, Object?>?> read(String key);
  Future<void> write(String key, Map<String, Object?> value);
  Future<void> remove(String key);
}

class PreferencesPersistenceService(final SharedPreferencesAsync preferences)
    implements LocalPersistenceService {
  factory platform() => PreferencesPersistenceService(SharedPreferencesAsync());
  @override
  Future<Map<String, Object?>?> read(String key) async {
    final text = await preferences.getString('tw.v1.$key');
    return text == null ? null : Map<String, Object?>.from(jsonDecode(text) as Map);
  }

  @override
  Future<void> write(String key, Map<String, Object?> value) =>
      preferences.setString('tw.v1.$key', jsonEncode(value));
  @override
  Future<void> remove(String key) => preferences.remove('tw.v1.$key');
}

abstract interface class AuthenticationService() {
  Future<String> authenticate();
}

class const MockAuthService() implements AuthenticationService {
  @override
  Future<String> authenticate() async => 'alex@torquewrench.demo';
}

abstract interface class Simulation() {
  bool get offline;
  Future<void> wait({bool write = false});
}

class DemoSimulation({
  @override var bool offline = false,
  var bool failWrites = false,
  var bool failLoads = false,
  final Duration delay = const Duration(milliseconds: 240),
}) implements Simulation {
  @override
  Future<void> wait({bool write = false}) async {
    await Future<void>.delayed(delay);
    if ((offline && write) || (write ? failWrites : failLoads)) {
      throw const AppFailure(
        FailureKind.connectivity,
        'Connection unavailable. Retry when connected.',
      );
    }
  }
}
