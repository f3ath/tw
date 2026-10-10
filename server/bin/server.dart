import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:tw_server/src/application/app_config.dart';
import 'package:tw_server/src/application/app.dart';
import 'package:tw_server/src/http/http_server_harness.dart';
import 'package:tw_server/src/io/process_signal.dart';
import 'package:tw_server/src/log/log.dart';
import 'package:tw_server/src/log/std_err_log.dart';

Future<void> main(List<String> args) async {
  final log = StdErrLog(minLevel: LogLevel.debug);
  final env = DotEnv(includePlatformEnvironment: true, quiet: true)..load(['.env', 'server/.env']);
  final baseUri = Uri.parse('http://localhost:8080/api/v0');
  final config = AppConfig(
    baseUri: baseUri,
    googleOAuthClientId: _requiredEnv(env, 'GOOGLE_OAUTH_CLIENT_ID'),
    googleOAuthClientSecret: _requiredEnv(env, 'GOOGLE_OAUTH_CLIENT_SECRET'),
    databaseHost: 'localhost',
    databasePort: 5432,
    databaseName: 'tw_e2e',
    databaseUsername: 'tw',
    databasePassword: 'tw',
  );

  final server = HttpServerHarness();
  final app = App(config: config, log: log);
  log.info("Starting server...");
  await server.start(app.call);
  log.info('Starting application...');
  await app.start();
  log.info("Application started.");

  final sig = await firstProcessSignal([ProcessSignal.sigterm, ProcessSignal.sigint]);
  log.info("Received signal: $sig");
  await server.stop();
  log.info('Server stopped.');
}

String _requiredEnv(DotEnv env, String key) =>
    env.getOrElse(key, () => throw StateError('Missing required environment variable: $key'));
