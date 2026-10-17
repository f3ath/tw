import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:tw_server/src/app/app.dart';
import 'package:tw_server/src/app/app_config.dart';
import 'package:tw_server/src/http/http_server_harness.dart';
import 'package:tw_server/src/io/process_signal.dart';
import 'package:tw_server/src/log/log.dart';
import 'package:tw_server/src/log/sink_log.dart';

Future<void> main(List<String> args) async {
  final log = SinkLog(stderr, minLevel: LogLevel.debug);
  final server = HttpServerHarness();
  final dotEnv = DotEnv(includePlatformEnvironment: true)..load();
  final appConfig = AppConfig.from(dotEnv.get);
  final app = App(appConfig, log: log);
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

extension on DotEnv {
  String get(String key, {String Function()? orElse}) => getOrElse(
    key,
    orElse ?? () => throw StateError('Missing required environment variable: $key'),
  );
}
