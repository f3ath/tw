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
  /// Loads platform variables and optional dotenv files, with later files taking precedence.
  factory fromEnv({Iterable<String> filenames = const ['.env']}) {
    final env = DotEnv(includePlatformEnvironment: true)..load(filenames);
    return AppConfig(
      baseUri: Uri.parse(env.getOrElse('BASE_URI', () => 'http://localhost:8080/api/v0')),
      googleOAuthClientId: env.required('GOOGLE_OAUTH_CLIENT_ID'),
      googleOAuthClientSecret: env.required('GOOGLE_OAUTH_CLIENT_SECRET'),
      databaseHost: env.getOrElse('DATABASE_HOST', () => 'localhost'),
      databasePort: int.parse(env.getOrElse('DATABASE_PORT', () => '5432')),
      databaseName: env.getOrElse('DATABASE_NAME', () => 'tw_e2e'),
      databaseUsername: env.getOrElse('DATABASE_USERNAME', () => 'tw'),
      databasePassword: env.getOrElse('DATABASE_PASSWORD', () => 'tw'),
    );
  }
}

extension on DotEnv {
  String required(String key) =>
      getOrElse(key, () => throw StateError('Missing required environment variable: $key'));
}
