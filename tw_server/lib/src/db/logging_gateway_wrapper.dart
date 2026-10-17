import 'package:migrant/migrant.dart';
import 'package:tw_server/src/log/log.dart';

class LoggingGatewayWrapper(final DatabaseGateway gateway, final Log log)
    implements DatabaseGateway {
  @override
  Future<String?> currentVersion() async {
    final version = await gateway.currentVersion();
    log.info('Database is at version $version.');
    return version;
  }

  @override
  Future<void> initialize(Migration migration) {
    log.info('Initializing DB with version ${migration.version}...');
    return gateway.initialize(migration);
  }

  @override
  Future<void> upgrade(String version, Migration migration) {
    log.info('Upgrading DB $version -> ${migration.version}...');
    return gateway.upgrade(version, migration);
  }
}
