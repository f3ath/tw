import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:http_interop_io/http_interop_io.dart';
import 'package:server/src/k8s/container_probes.dart';
import 'package:server/src/log/log.dart';
import 'package:server/src/log/sink_log.dart';
import 'package:server/src/server/server.dart';
import 'package:server/src/server/server_config.dart';
import 'package:server/src/streams/first_event.dart';

Future<void> main(List<String> args) async {
  final log = SinkLog(stderr, minLevel: LogLevel.debug);
  final dotEnv = DotEnv(includePlatformEnvironment: true)..load();
  final serverConfig = ServerConfig.from(dotEnv.get);
  final server = Server(serverConfig, log: log);
  final handler = containerProbesMiddleware(server, server.handler);

  final address = InternetAddress.anyIPv4;
  final port = 8080;

  log.info("Starting HTTP at ${address.address}:$port...");
  final httpServer = await HttpServer.bind(address, port);
  httpServer.listenInterop(handler);

  log.info('Starting services...');
  await server.start();
  log.info("Services started. Ready.");

  final sig = await firstEvent(
    [ProcessSignal.sigterm, ProcessSignal.sigint].map((it) => it.watch()),
  );
  log.info("Received signal: $sig");
  log.info("Stopping services...");
  await server.stop();
  log.info("Stopping HTTP...");
  await httpServer.close();
  log.info("Bye.");
}

extension on DotEnv {
  String get(String key, {String Function()? orElse}) => getOrElse(
    key,
    orElse ?? () => throw StateError('Missing required environment variable: $key'),
  );
}
