class AppConfig({
  required final Uri baseUri,
  required final String googleOAuthClientId,
  required final String googleOAuthClientSecret,
  required final String databaseHost,
  required final int databasePort,
  required final String databaseName,
  required final String databaseUsername,
  required final String databasePassword,
  final Duration sessionCleanupInterval = const Duration(minutes: 1),
  final Duration pendingSessionMaxAge = const Duration(minutes: 15),
}) {
  this {
    if (sessionCleanupInterval <= Duration.zero) {
      throw ArgumentError.value(
        sessionCleanupInterval,
        'sessionCleanupInterval',
        'Must be positive',
      );
    }
    if (pendingSessionMaxAge <= Duration.zero) {
      throw ArgumentError.value(pendingSessionMaxAge, 'pendingSessionMaxAge', 'Must be positive');
    }
  }

  factory from(ValueReader get) => AppConfig(
    baseUri: Uri.parse(get('BASE_URI', orElse: () => 'http://localhost:8080/api/v0')),
    googleOAuthClientId: get('GOOGLE_OAUTH_CLIENT_ID'),
    googleOAuthClientSecret: get('GOOGLE_OAUTH_CLIENT_SECRET'),
    databaseHost: get('DATABASE_HOST', orElse: () => 'localhost'),
    databasePort: int.parse(get('DATABASE_PORT', orElse: () => '5432')),
    databaseName: get('DATABASE_NAME', orElse: () => 'tw_e2e'),
    databaseUsername: get('DATABASE_USERNAME', orElse: () => 'tw'),
    databasePassword: get('DATABASE_PASSWORD', orElse: () => 'tw'),
    sessionCleanupInterval: Duration(
      seconds: int.parse(get('SESSION_CLEANUP_INTERVAL_SECONDS', orElse: () => '60')),
    ),
    pendingSessionMaxAge: Duration(
      seconds: int.parse(get('PENDING_SESSION_MAX_AGE_SECONDS', orElse: () => '900')),
    ),
  );
}

typedef ValueReader = String Function(String key, {String Function()? orElse});
