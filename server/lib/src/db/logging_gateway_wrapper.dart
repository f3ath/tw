import 'package:migrant/migrant.dart';

class LoggingGatewayWrapper implements DatabaseGateway {
  LoggingGatewayWrapper(this.gateway);

  final DatabaseGateway gateway;

  @override
  Future<String?> currentVersion() async {
    final version = await gateway.currentVersion();
    print('Database is at version $version.');
    return version;
  }

  @override
  Future<void> initialize(Migration migration) {
    print('Initializing DB with version ${migration.version}...');
    return gateway.initialize(migration);
  }

  @override
  Future<void> upgrade(String version, Migration migration) {
    print('Upgrading DB $version -> ${migration.version}...');
    return gateway.upgrade(version, migration);
  }
}
