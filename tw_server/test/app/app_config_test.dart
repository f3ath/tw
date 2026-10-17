import 'dart:io';

import 'package:test/test.dart';
import 'package:tw_server/src/app/app_config.dart';

void main() {
  late Directory directory;
  late File envFile;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('tw-config-');
    envFile = File('${directory.path}/.env');
  });

  tearDown(() => directory.deleteSync(recursive: true));

  AppConfig load(String contents) {
    envFile.writeAsStringSync(contents);
    return AppConfig.fromEnv(filenames: [envFile.path]);
  }

  test('uses local defaults for absent or empty optional values', () {
    final config = load('''
GOOGLE_OAUTH_CLIENT_ID=test-client
GOOGLE_OAUTH_CLIENT_SECRET=test-secret
BASE_URI=
DATABASE_HOST=
DATABASE_PORT=
DATABASE_NAME=
DATABASE_USERNAME=
DATABASE_PASSWORD=
''');

    expect(config.baseUri, Uri.parse('http://localhost:8080/api/v0'));
    expect(config.databaseHost, 'localhost');
    expect(config.databasePort, 5432);
    expect(config.databaseName, 'tw_e2e');
    expect(config.databaseUsername, 'tw');
    expect(config.databasePassword, 'tw');
  });

  test('loads environment overrides', () {
    final config = load('''
GOOGLE_OAUTH_CLIENT_ID=test-client
GOOGLE_OAUTH_CLIENT_SECRET=test-secret
BASE_URI=https://example.com/api/v0
DATABASE_HOST=postgres
DATABASE_PORT=5433
DATABASE_NAME=production
DATABASE_USERNAME=app
DATABASE_PASSWORD=secret
''');

    expect(config.googleOAuthClientId, 'test-client');
    expect(config.googleOAuthClientSecret, 'test-secret');
    expect(config.baseUri, Uri.parse('https://example.com/api/v0'));
    expect(config.databaseHost, 'postgres');
    expect(config.databasePort, 5433);
    expect(config.databaseName, 'production');
    expect(config.databaseUsername, 'app');
    expect(config.databasePassword, 'secret');
  });

  for (final key in ['GOOGLE_OAUTH_CLIENT_ID', 'GOOGLE_OAUTH_CLIENT_SECRET']) {
    test('requires $key', () {
      expect(
        () => load('''
GOOGLE_OAUTH_CLIENT_ID=test-client
GOOGLE_OAUTH_CLIENT_SECRET=test-secret
$key=
'''),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Missing required environment variable: $key',
          ),
        ),
      );
    });
  }
}
