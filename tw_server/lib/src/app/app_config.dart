import 'package:dotenv/dotenv.dart';

class AppConfig({
  required final Uri baseUri,
  required final String googleOAuthClientId,
  required final String googleOAuthClientSecret,
  required final String databaseHost,
  required final int databasePort,
  required final String databaseName,
  required final String databaseUsername,
  required final String databasePassword,
}) {
  factory from(ValueReader get) => AppConfig(
    baseUri: Uri.parse(get('BASE_URI', orElse: () => 'http://localhost:8080/api/v0')),
    googleOAuthClientId: get('GOOGLE_OAUTH_CLIENT_ID'),
    googleOAuthClientSecret: get('GOOGLE_OAUTH_CLIENT_SECRET'),
    databaseHost: get('DATABASE_HOST', orElse: () => 'localhost'),
    databasePort: int.parse(get('DATABASE_PORT', orElse: () => '5432')),
    databaseName: get('DATABASE_NAME', orElse: () => 'tw_e2e'),
    databaseUsername: get('DATABASE_USERNAME', orElse: () => 'tw'),
    databasePassword: get('DATABASE_PASSWORD', orElse: () => 'tw'),
  );
}

typedef ValueReader = String Function(String key, {String Function()? orElse});
