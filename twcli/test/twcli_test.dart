import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:twcli/twcli.dart';

void main() {
  test('auth login creates a session, stores it, and prints browser URL', () async {
    final client = FakeTwClient();
    final store = MemorySessionStore();
    final opened = <Uri>[];
    final out = _IOSinkBuffer();
    final code = await TwCli(
      client: client,
      sessionStore: store,
      browserOpener: BrowserOpener((uri) async => opened.add(uri)),
    ).run(['auth', 'login', '--no-wait'], stdin: _stdin(), stdout: out, stderr: _IOSinkBuffer());

    expect(code, 0);
    expect((await store.read())!.id, 'session-1');
    expect(opened, [Uri.parse('https://accounts.example/auth')]);
    expect(out.text, contains('TWCLI  AUTH'));
    expect(out.text, contains('open https://accounts.example/auth'));
  });

  test('vehicles create uses client and renders detail screen', () async {
    final client = FakeTwClient();
    final out = _IOSinkBuffer();

    final code = await TwCli(client: client, sessionStore: MemorySessionStore()).run(
      ['vehicles', 'create', '--name', 'Accord', '--manufacture-date', '2021-06-02'],
      stdin: _stdin(),
      stdout: out,
      stderr: _IOSinkBuffer(),
    );

    expect(code, 0);
    expect(client.vehicles.single.name, 'Accord');
    expect(out.text, contains('TWCLI  VEHICLE'));
    expect(out.text, contains('manufacture_date'));
    expect(out.text, contains('2021-06-02'));
  });

  test('schedules update passes optional fields through', () async {
    final client = FakeTwClient();
    client.schedules.add(
      const ScheduleInfo(
        id: 'schedule-1',
        vehicleId: 'vehicle-1',
        name: 'Oil',
        intervalMiles: 3000,
        intervalMonths: 3,
        details: 'Old',
      ),
    );
    final out = _IOSinkBuffer();

    final code = await TwCli(client: client, sessionStore: MemorySessionStore()).run(
      ['schedules', 'update', 'vehicle-1', 'schedule-1', '--details', 'Synthetic oil'],
      stdin: _stdin(),
      stdout: out,
      stderr: _IOSinkBuffer(),
    );

    expect(code, 0);
    expect(client.schedules.single.details, 'Synthetic oil');
    expect(out.text, contains('Synthetic oil'));
  });

  test('dashboard renders k9s-like shell with stored session and vehicles', () async {
    final client = FakeTwClient()
      ..vehicles.add(
        const VehicleInfo(id: 'vehicle-1', name: 'Accord', manufactureDate: '2021-06-02'),
      );
    final store = MemorySessionStore()
      ..session = const SessionInfo(id: 'session-1', bearer: 'bearer');
    final out = _IOSinkBuffer();

    final code = await TwCli(
      client: client,
      sessionStore: store,
    ).run([], stdin: _stdin(), stdout: out, stderr: _IOSinkBuffer());

    expect(code, 0);
    expect(out.text, contains('TWCLI  TW'));
    expect(out.text, contains('CMD'));
    expect(out.text, contains('Accord'));
  });
}

class FakeTwClient() implements TwClient {
  final sessions = <SessionInfo>[];
  final vehicles = <VehicleInfo>[];
  final schedules = <ScheduleInfo>[];

  @override
  Future<SessionInfo?> createSession() async {
    final session = SessionInfo(
      id: 'session-1',
      bearer: 'bearer-1',
      redirect: Uri.parse('https://accounts.example/auth'),
    );
    sessions.add(session);
    return session;
  }

  @override
  Future<List<SessionInfo>> listSessions() async => sessions;

  @override
  Future<void> deleteSession(String id) async {
    sessions.removeWhere((s) => s.id == id);
  }

  @override
  Future<VehicleInfo> createVehicle({
    required String name,
    required DateTime manufactureDate,
  }) async {
    final vehicle = VehicleInfo(
      id: 'vehicle-${vehicles.length + 1}',
      name: name,
      manufactureDate: manufactureDate.toIso8601String().split('T').first,
    );
    vehicles.add(vehicle);
    return vehicle;
  }

  @override
  Future<void> deleteVehicle(String id) async {
    vehicles.removeWhere((v) => v.id == id);
  }

  @override
  Future<VehicleInfo> fetchVehicle(String id) async => vehicles.singleWhere((v) => v.id == id);

  @override
  Future<List<VehicleInfo>> listVehicles() async => vehicles;

  @override
  Future<VehicleInfo?> updateVehicle(String id, {String? name, DateTime? manufactureDate}) async {
    final index = vehicles.indexWhere((v) => v.id == id);
    if (index == -1) {
      return null;
    }
    return vehicles[index] = VehicleInfo(
      id: id,
      name: name ?? vehicles[index].name,
      manufactureDate:
          manufactureDate?.toIso8601String().split('T').first ?? vehicles[index].manufactureDate,
    );
  }

  @override
  Future<ScheduleInfo> createSchedule(
    String vehicleId, {
    required String name,
    required int intervalMiles,
    required int intervalMonths,
    required String details,
  }) async {
    final schedule = ScheduleInfo(
      id: 'schedule-${schedules.length + 1}',
      vehicleId: vehicleId,
      name: name,
      intervalMiles: intervalMiles,
      intervalMonths: intervalMonths,
      details: details,
    );
    schedules.add(schedule);
    return schedule;
  }

  @override
  Future<void> deleteSchedule(String id) async {
    schedules.removeWhere((s) => s.id == id);
  }

  @override
  Future<List<ScheduleInfo>> listSchedules(String vehicleId) async =>
      schedules.where((s) => s.vehicleId == vehicleId).toList();

  @override
  Future<ScheduleInfo?> updateSchedule(
    String vehicleId,
    String scheduleId, {
    String? name,
    int? intervalMiles,
    int? intervalMonths,
    String? details,
  }) async {
    final index = schedules.indexWhere((s) => s.id == scheduleId && s.vehicleId == vehicleId);
    if (index == -1) {
      return null;
    }
    return schedules[index] = ScheduleInfo(
      id: scheduleId,
      vehicleId: vehicleId,
      name: name ?? schedules[index].name,
      intervalMiles: intervalMiles ?? schedules[index].intervalMiles,
      intervalMonths: intervalMonths ?? schedules[index].intervalMonths,
      details: details ?? schedules[index].details,
    );
  }
}

Stdin _stdin() => stdin;

class _IOSinkBuffer() implements IOSink {
  final _buffer = StringBuffer();

  String get text => _buffer.toString();

  @override
  Encoding encoding = utf8;

  @override
  void add(List<int> data) => _buffer.write(encoding.decode(data));

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final data in stream) {
      add(data);
    }
  }

  @override
  Future<void> close() async {}

  @override
  Future<void> get done async {}

  @override
  Future<void> flush() async {}

  @override
  void write(Object? object) => _buffer.write(object);

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) {
    _buffer.writeAll(objects, separator);
  }

  @override
  void writeCharCode(int charCode) {
    _buffer.writeCharCode(charCode);
  }

  @override
  void writeln([Object? object = '']) {
    _buffer.writeln(object);
  }
}
