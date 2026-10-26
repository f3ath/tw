import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/data/services/services.dart';

class FakePreferences() extends Fake implements SharedPreferencesAsync {
  final values = <String, String>{};
  @override
  Future<String?> getString(String key) async => values[key];
  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

void main() {
  test('persistence service serializes through injected platform boundary', () async {
    final preferences = FakePreferences();
    final service = PreferencesPersistenceService(preferences);
    expect(await service.read('session'), isNull);
    await service.write('session', {
      'identity': 'fake',
      'nested': [1, true],
    });
    expect(preferences.values.keys, ['tw.v1.session']);
    expect(await service.read('session'), {
      'identity': 'fake',
      'nested': [1, true],
    });
    await service.remove('session');
    expect(await service.read('session'), isNull);
  });
}
