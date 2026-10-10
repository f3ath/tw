import 'dart:io';

import 'package:migrant/migrant.dart';
import 'package:migrant_db_postgresql/migrant_db_postgresql.dart';
import 'package:migrant_source_fs/migrant_source_fs.dart';
import 'package:postgres/postgres.dart';
import 'package:tw_server/src/log/log.dart';

import 'logging_gateway_wrapper.dart';

Future<void> applyMigrations(Connection db, Log log) async {
  final format = FileNameFormat(RegExp(r'\d{4}'));
  final directory = Directory('assets/db');
  final migrations = LocalFilesystem();
  log.info('Reading all migrations from $directory:');
  final loaded = await migrations.load(
    directory,
    format,
    split: (sql) => sql.split('\n\n').where((it) => it.trim().isNotEmpty).toList(),
  );

  log.info('Loaded $loaded migrations.');
  await Database(LoggingGatewayWrapper(PostgreSQLGateway(db), log)).upgrade(migrations);
  log.info('Migrations applied.');
}
