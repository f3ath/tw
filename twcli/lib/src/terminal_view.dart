import 'models.dart';

class TerminalView() {
  String dashboard({SessionInfo? session, required List<VehicleInfo> vehicles}) => screen(
    title: 'TW',
    context: session == null ? 'not authenticated' : 'session ${shortId(session.id)}',
    commands: const ['auth login', 'sessions', 'vehicles', 'schedules <vehicle-id>'],
    columns: const ['ID', 'NAME', 'MANUFACTURE DATE'],
    rows: vehicles.map((v) => [shortId(v.id), v.name, v.manufactureDate]).toList(),
  );

  String sessions(List<SessionInfo> sessions, {String? currentId}) => screen(
    title: 'SESSIONS',
    context: currentId == null ? 'no stored session' : 'current ${shortId(currentId)}',
    commands: const ['auth login', 'sessions delete <id>', 'auth logout'],
    columns: const ['ID', 'CURRENT', 'BEARER'],
    rows: sessions
        .map((s) => [shortId(s.id), s.id == currentId ? '*' : '', s.bearer == null ? '' : 'set'])
        .toList(),
  );

  String vehicles(List<VehicleInfo> vehicles) => screen(
    title: 'VEHICLES',
    context: '${vehicles.length} item(s)',
    commands: const [
      'vehicles create',
      'vehicles show <id>',
      'vehicles update <id>',
      'vehicles delete <id>',
    ],
    columns: const ['ID', 'NAME', 'MANUFACTURE DATE'],
    rows: vehicles.map((v) => [shortId(v.id), v.name, v.manufactureDate]).toList(),
  );

  String vehicle(VehicleInfo vehicle) => screen(
    title: 'VEHICLE',
    context: vehicle.id,
    commands: const ['vehicles update <id>', 'schedules <vehicle-id>'],
    columns: const ['FIELD', 'VALUE'],
    rows: [
      ['id', vehicle.id],
      ['name', vehicle.name],
      ['manufacture_date', vehicle.manufactureDate],
    ],
  );

  String schedules(String vehicleId, List<ScheduleInfo> schedules) => screen(
    title: 'SCHEDULES',
    context: 'vehicle ${shortId(vehicleId)}',
    commands: const [
      'schedules create <vehicle-id>',
      'schedules update <vehicle-id> <id>',
      'schedules delete <id>',
    ],
    columns: const ['ID', 'NAME', 'MILES', 'MONTHS', 'DETAILS'],
    rows: schedules
        .map(
          (s) => [
            shortId(s.id),
            s.name,
            s.intervalMiles.toString(),
            s.intervalMonths.toString(),
            s.details,
          ],
        )
        .toList(),
  );

  String message(String title, String message) => screen(
    title: title,
    context: message,
    commands: const ['twcli --help'],
    columns: const ['STATUS'],
    rows: [
      [message],
    ],
  );

  String screen({
    required String title,
    required String context,
    required List<String> commands,
    required List<String> columns,
    required List<List<String>> rows,
  }) {
    final buffer = StringBuffer()
      ..writeln('TWCLI  $title')
      ..writeln('CTX    $context')
      ..writeln('CMD    ${commands.join(' | ')}')
      ..writeln(''.padRight(80, '-'))
      ..writeln(_row(_widths(columns, rows), columns));
    for (final row in rows) {
      buffer.writeln(_row(_widths(columns, rows), row));
    }
    return buffer.toString();
  }

  List<int> _widths(List<String> columns, List<List<String>> rows) => [
    for (var column = 0; column < columns.length; column++)
      [
            columns[column].length,
            for (final row in rows)
              if (column < row.length) row[column].length,
          ].reduce((a, b) => a > b ? a : b) +
          2,
  ];

  String _row(List<int> widths, List<String> values) {
    return [
      for (var i = 0; i < widths.length; i++)
        (i < values.length ? values[i] : '').padRight(widths[i]),
    ].join(' ');
  }
}

String shortId(String id) => id.length <= 8 ? id : id.substring(0, 8);
