import 'package:postgres/postgres.dart';
import 'package:server/src/app/app_config.dart';

extension type SystemConnection(Connection _connection) implements Connection {
  static Future<SystemConnection> fromConfig(AppConfig config) async => SystemConnection(
    await _openConnection(
      config,
      username: config.databaseSystemUsername,
      password: config.databaseSystemPassword,
    ),
  );
}

extension type TenantConnection(Connection _connection) implements Connection {
  static Future<TenantConnection> fromConfig(AppConfig config) async => TenantConnection(
    await _openConnection(
      config,
      username: config.databaseTenantUsername,
      password: config.databaseTenantPassword,
    ),
  );
}

Future<Connection> _openConnection(
  AppConfig config, {
  required String username,
  required String password,
}) => Connection.open(
  Endpoint(
    host: config.databaseHost,
    port: config.databasePort,
    database: config.databaseName,
    username: username,
    password: password,
  ),
  settings: ConnectionSettings(sslMode: SslMode.disable),
);
