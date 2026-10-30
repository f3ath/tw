class ServerConfig({
  required final Uri baseUri,
  required final String googleOAuthClientId,
  required final String googleOAuthClientSecret,
  required final String databaseHost,
  required final int databasePort,
  required final String databaseName,
  required final String databaseSystemUsername,
  required final String databaseSystemPassword,
  required final String databaseTenantUsername,
  required final String databaseTenantPassword,
  required final String instanceType,
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

  factory from(ValueReader get) => ServerConfig(
    baseUri: Uri.parse(get('BASE_URI', orElse: () => 'http://localhost:8080/api/v0')),
    googleOAuthClientId: get('GOOGLE_OAUTH_CLIENT_ID'),
    googleOAuthClientSecret: get('GOOGLE_OAUTH_CLIENT_SECRET'),
    databaseHost: get('DATABASE_HOST', orElse: () => 'localhost'),
    databasePort: int.parse(get('DATABASE_PORT', orElse: () => '5432')),
    databaseName: get('DATABASE_NAME', orElse: () => 'tw_e2e'),
    databaseSystemUsername: get('DATABASE_SYSTEM_USERNAME', orElse: () => 'tw_system'),
    databaseSystemPassword: get('DATABASE_SYSTEM_PASSWORD', orElse: () => 'tw_system'),
    databaseTenantUsername: get('DATABASE_TENANT_USERNAME', orElse: () => 'tw_tenant'),
    databaseTenantPassword: get('DATABASE_TENANT_PASSWORD', orElse: () => 'tw_tenant'),
    sessionCleanupInterval: Duration(
      seconds: int.parse(get('SESSION_CLEANUP_INTERVAL_SECONDS', orElse: () => '60')),
    ),
    pendingSessionMaxAge: Duration(
      seconds: int.parse(get('PENDING_SESSION_MAX_AGE_SECONDS', orElse: () => '900')),
    ),
    instanceType: get('INSTANCE_TYPE', orElse: () => 'prod'),
  );
}

typedef ValueReader = String Function(String key, {String Function()? orElse});
