import 'package:postgres/postgres.dart';
import 'package:tw_server/src/app/app_config.dart';

Future<Connection> connectionFromConfig(AppConfig config) => Connection.open(
  Endpoint(
    host: config.databaseHost,
    port: config.databasePort,
    database: config.databaseName,
    username: config.databaseUsername,
    password: config.databasePassword,
  ),
  settings: ConnectionSettings(sslMode: SslMode.disable),
);
