import 'dart:io';

import 'package:args/args.dart';

import 'client.dart';
import 'models.dart';
import 'session_store.dart';
import 'terminal_view.dart';

class TwCli({
  required final TwClient client,
  required final SessionStore sessionStore,
  final BrowserOpener? browserOpener,
}) {
  factory production() {
    final store = FileSessionStore.defaultLocation();
    return TwCli(
      client: TwApiClientAdapter.forServer(
        baseUri: Uri.parse('http://localhost:8080/api/v0'),
        sessionStore: store,
      ),
      sessionStore: store,
    );
  }

  final TwClient _client = client;
  final SessionStore _sessionStore = sessionStore;
  final BrowserOpener _browserOpener = browserOpener ?? BrowserOpener.platform;
  final _view = TerminalView();

  Future<int> run(
    List<String> args, {
    required Stdin stdin,
    required IOSink stdout,
    required IOSink stderr,
  }) async {
    try {
      final parsed = _parser.parse(args);
      final rest = parsed.rest;
      if (parsed['help'] as bool) {
        stdout.writeln(_usage);
        return 0;
      }
      if (rest.isEmpty) {
        return await _dashboard(stdout);
      }

      return switch (rest.first) {
        'auth' => await _auth(rest.skip(1).toList(), parsed, stdin, stdout),
        'sessions' => await _sessions(rest.skip(1).toList(), stdout),
        'vehicles' => await _vehicles(rest.skip(1).toList(), parsed, stdout),
        'schedules' => await _schedules(rest.skip(1).toList(), parsed, stdout),
        _ => _unknown(rest.first, stderr),
      };
    } on FormatException catch (e) {
      stderr.writeln(e.message);
      stderr.writeln(_usage);
      return 64;
    } on Object catch (e) {
      stderr.writeln(e);
      return 1;
    }
  }

  Future<int> _dashboard(IOSink stdout) async {
    final session = await _sessionStore.read();
    final vehicles = session == null ? <VehicleInfo>[] : await _client.listVehicles();
    stdout.write(_view.dashboard(session: session, vehicles: vehicles));
    return 0;
  }

  Future<int> _auth(List<String> args, ArgResults parsed, Stdin stdin, IOSink stdout) async {
    final command = args.firstOrNull ?? 'login';
    if (command == 'logout') {
      final session = await _sessionStore.read();
      if (session?.id != null) {
        await _client.deleteSession(session!.id);
      }
      await _sessionStore.clear();
      stdout.write(_view.message('AUTH', 'logged out'));
      return 0;
    }
    if (command != 'login') {
      throw FormatException('Unknown auth command: $command');
    }

    final session = await _client.createSession();
    if (session == null) {
      throw StateError('Server did not create a session');
    }
    await _sessionStore.write(session);
    final redirect = session.redirect;
    if (redirect != null && !(parsed['no-browser'] as bool)) {
      await _browserOpener.open(redirect);
    }
    stdout.write(
      _view.message('AUTH', redirect == null ? 'session created' : 'open ${redirect.toString()}'),
    );
    if (!(parsed['no-wait'] as bool)) {
      stdout.writeln('Press Enter after the browser callback completes.');
      await stdin.first;
    }
    return 0;
  }

  Future<int> _sessions(List<String> args, IOSink stdout) async {
    if (args.firstOrNull == 'delete') {
      final id = _required(args, 1, 'session id');
      await _client.deleteSession(id);
      final current = await _sessionStore.read();
      if (current?.id == id) {
        await _sessionStore.clear();
      }
      stdout.write(_view.message('SESSIONS', 'deleted $id'));
      return 0;
    }
    final current = await _sessionStore.read();
    stdout.write(_view.sessions(await _client.listSessions(), currentId: current?.id));
    return 0;
  }

  Future<int> _vehicles(List<String> args, ArgResults parsed, IOSink stdout) async {
    final command = args.firstOrNull ?? 'list';
    switch (command) {
      case 'list':
        stdout.write(_view.vehicles(await _client.listVehicles()));
      case 'show':
        stdout.write(_view.vehicle(await _client.fetchVehicle(_required(args, 1, 'vehicle id'))));
      case 'create':
        final vehicle = await _client.createVehicle(
          name: _requiredOption(parsed, 'name'),
          manufactureDate: DateTime.parse(_requiredOption(parsed, 'manufacture-date')),
        );
        stdout.write(_view.vehicle(vehicle));
      case 'update':
        final vehicle = await _client.updateVehicle(
          _required(args, 1, 'vehicle id'),
          name: parsed['name'] as String?,
          manufactureDate: (parsed['manufacture-date'] as String?) == null
              ? null
              : DateTime.parse(parsed['manufacture-date'] as String),
        );
        stdout.write(
          _view.vehicle(vehicle ?? await _client.fetchVehicle(_required(args, 1, 'vehicle id'))),
        );
      case 'delete':
        final id = _required(args, 1, 'vehicle id');
        await _client.deleteVehicle(id);
        stdout.write(_view.message('VEHICLES', 'deleted $id'));
      default:
        throw FormatException('Unknown vehicles command: $command');
    }
    return 0;
  }

  Future<int> _schedules(List<String> args, ArgResults parsed, IOSink stdout) async {
    final command = args.firstOrNull ?? 'list';
    switch (command) {
      case 'list':
        final vehicleId = _required(args, 1, 'vehicle id');
        stdout.write(_view.schedules(vehicleId, await _client.listSchedules(vehicleId)));
      case 'create':
        final vehicleId = _required(args, 1, 'vehicle id');
        final schedule = await _client.createSchedule(
          vehicleId,
          name: _requiredOption(parsed, 'name'),
          intervalMiles: int.parse(_requiredOption(parsed, 'interval-miles')),
          intervalMonths: int.parse(_requiredOption(parsed, 'interval-months')),
          details: _requiredOption(parsed, 'details'),
        );
        stdout.write(_view.schedules(vehicleId, [schedule]));
      case 'update':
        final vehicleId = _required(args, 1, 'vehicle id');
        final schedule = await _client.updateSchedule(
          vehicleId,
          _required(args, 2, 'schedule id'),
          name: parsed['name'] as String?,
          intervalMiles: (parsed['interval-miles'] as String?) == null
              ? null
              : int.parse(parsed['interval-miles'] as String),
          intervalMonths: (parsed['interval-months'] as String?) == null
              ? null
              : int.parse(parsed['interval-months'] as String),
          details: parsed['details'] as String?,
        );
        stdout.write(_view.schedules(vehicleId, schedule == null ? [] : [schedule]));
      case 'delete':
        final id = _required(args, 1, 'schedule id');
        await _client.deleteSchedule(id);
        stdout.write(_view.message('SCHEDULES', 'deleted $id'));
      default:
        throw FormatException('Unknown schedules command: $command');
    }
    return 0;
  }

  int _unknown(String command, IOSink stderr) {
    stderr.writeln('Unknown command: $command');
    stderr.writeln(_usage);
    return 64;
  }
}

typedef BrowserOpen = Future<void> Function(Uri uri);

class BrowserOpener(final BrowserOpen _open) {
  Future<void> open(Uri uri) => _open(uri);

  static BrowserOpener get platform => BrowserOpener((uri) async {
    if (Platform.isMacOS) {
      await Process.run('open', [uri.toString()]);
    } else if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', uri.toString()]);
    } else {
      await Process.run('xdg-open', [uri.toString()]);
    }
  });
}

ArgParser get _parser => ArgParser()
  ..addFlag('help', abbr: 'h', negatable: false)
  ..addFlag('no-browser', negatable: false)
  ..addFlag('no-wait', negatable: false)
  ..addOption('name')
  ..addOption('manufacture-date')
  ..addOption('interval-miles')
  ..addOption('interval-months')
  ..addOption('details');

String _required(List<String> args, int index, String label) {
  if (args.length <= index) {
    throw FormatException('Missing $label');
  }
  return args[index];
}

String _requiredOption(ArgResults parsed, String name) {
  final value = parsed[name] as String?;
  if (value == null || value.isEmpty) {
    throw FormatException('Missing --$name');
  }
  return value;
}

const _usage = '''
Usage:
  twcli auth login [--no-browser] [--no-wait]
  twcli auth logout
  twcli sessions
  twcli sessions delete <id>
  twcli vehicles [list]
  twcli vehicles show <id>
  twcli vehicles create --name <name> --manufacture-date <yyyy-mm-dd>
  twcli vehicles update <id> [--name <name>] [--manufacture-date <yyyy-mm-dd>]
  twcli vehicles delete <id>
  twcli schedules list <vehicle-id>
  twcli schedules create <vehicle-id> --name <name> --interval-miles <miles> --interval-months <months> --details <details>
  twcli schedules update <vehicle-id> <schedule-id> [--name <name>] [--interval-miles <miles>] [--interval-months <months>] [--details <details>]
  twcli schedules delete <id>
''';
