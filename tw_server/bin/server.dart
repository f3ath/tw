import 'dart:io';

import 'package:tw_server/src/app/app.dart';
import 'package:tw_server/src/app/app_config.dart';
import 'package:tw_server/src/http/http_server_harness.dart';
import 'package:tw_server/src/io/process_signal.dart';
import 'package:tw_server/src/log/log.dart';
import 'package:tw_server/src/log/sink_log.dart';

Future<void> main(List<String> args) async {
  final log = SinkLog(stderr, minLevel: LogLevel.debug);
  final server = HttpServerHarness();
  final app = App(AppConfig.fromEnv(), log: log);
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
