import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:server/src/http/http_server_harness.dart';
import 'package:server/src/k8s/container_probes.dart';
import 'package:server/src/log/log.dart';
import 'package:server/src/log/sink_log.dart';
import 'package:server/src/server/server.dart';
import 'package:server/src/server/server_config.dart';
import 'package:server/src/streams/first_event.dart';

Future<void> main(List<String> args) async {
  final log = SinkLog(stderr, minLevel: LogLevel.debug);
  final httpServer = HttpServerHarness();
  final dotEnv = DotEnv(includePlatformEnvironment: true)..load();
  final serverConfig = ServerConfig.from(dotEnv.get);
  final server = Server(serverConfig, log: log);
  final handler = containerProbesMiddleware(server, server.handler);
  try {
    log.info("Starting server...");
    await httpServer.start(handler);
    log.info('Starting server services...');
    await server.start();
    log.info("Server services started.");

    final sig = await firstEvent(
      [ProcessSignal.sigterm, ProcessSignal.sigint].map((it) => it.watch()),
    );
    log.info("Received signal: $sig");
  } catch (e, t) {
    log.error('Exception', error: e, stackTrace: t);
  } finally {
    try {
      await httpServer.stop();
    } catch (e, t) {
      log.error('Exception', error: e, stackTrace: t);
    } finally {
      await server.stop();
    }
    log.info('Server stopped.');
  }
}

extension on DotEnv {
  String get(String key, {String Function()? orElse}) => getOrElse(
    key,
    orElse ?? () => throw StateError('Missing required environment variable: $key'),
  );
}
