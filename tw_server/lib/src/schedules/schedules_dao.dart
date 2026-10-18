import 'package:postgres/postgres.dart';
import 'package:tw_server/src/time/clock.dart';

class SchedulesDAO(final Connection connection, {Clock clock = defaultClock}) {
  final _clock = clock;

  Future<ScheduleRecord?> create({
    required String id,
    required String vehicleId,
    required String userId,
    required String name,
    required int intervalMiles,
    required int intervalMonths,
    required String details,
  }) async {
    final schedule = ScheduleRecord(
      id: id,
      vehicleId: vehicleId,
      name: name,
      intervalMiles: intervalMiles,
      intervalMonths: intervalMonths,
      details: details,
    );
    final rows = await connection.execute(
      Sql.named('''
INSERT INTO schedules (id, owner_id, vehicle_id, name, interval_miles, interval_months, details, created_at, updated_at)
SELECT @id:text, owner_id, id, @name:text, @interval_miles:int4, @interval_months:int4, @details:text, @now:timestamp, @now:timestamp
FROM vehicles
WHERE id = @vehicle_id:text AND owner_id = @owner_id:text
RETURNING id
'''),
      parameters: {...schedule.toMap(), 'owner_id': userId, 'now': _clock()},
    );
    return rows.isEmpty ? null : schedule;
  }

  Future<List<ScheduleRecord>> fetchByVehicleIdAndUserId({
    required String vehicleId,
    required String userId,
  }) async {
    final rows = await connection.execute(
      Sql.named('''
SELECT id, vehicle_id, name, interval_miles, interval_months, details
FROM schedules
WHERE vehicle_id = @vehicle_id:text AND owner_id = @owner_id:text
ORDER BY created_at
'''),
      parameters: {'vehicle_id': vehicleId, 'owner_id': userId},
    );
    return rows.map((row) => ScheduleRecord.fromMap(row.toColumnMap())).toList();
  }

  Future<List<ScheduleRecord>> fetchByUserId(String userId) async {
    final rows = await connection.execute(
      Sql.named('''
SELECT id, vehicle_id, name, interval_miles, interval_months, details
FROM schedules
WHERE owner_id = @owner_id:text
ORDER BY created_at
'''),
      parameters: {'owner_id': userId},
    );
    return rows.map((row) => ScheduleRecord.fromMap(row.toColumnMap())).toList();
  }

  Future<ScheduleRecord?> update({
    required String id,
    required String vehicleId,
    required String userId,
    String? name,
    int? intervalMiles,
    int? intervalMonths,
    String? details,
  }) async {
    final rows = await connection.execute(
      Sql.named('''
UPDATE schedules
SET name = COALESCE(@name:text, name),
    interval_miles = COALESCE(@interval_miles:int4, interval_miles),
    interval_months = COALESCE(@interval_months:int4, interval_months),
    details = COALESCE(@details:text, details),
    updated_at = @now:timestamp
WHERE id = @id:text
  AND vehicle_id = @vehicle_id:text
  AND owner_id = @owner_id:text
RETURNING id, vehicle_id, name, interval_miles, interval_months, details
'''),
      parameters: {
        'id': id,
        'vehicle_id': vehicleId,
        'owner_id': userId,
        'name': name,
        'interval_miles': intervalMiles,
        'interval_months': intervalMonths,
        'details': details,
        'now': _clock(),
      },
    );
    if (rows.isEmpty) {
      return null;
    }
    return ScheduleRecord.fromMap(rows.single.toColumnMap());
  }

  Future<bool> delete({required String id, required String userId}) async {
    final rows = await connection.execute(
      Sql.named('''
DELETE FROM schedules
WHERE id = @id:text
  AND owner_id = @owner_id:text
RETURNING id
'''),
      parameters: {'id': id, 'owner_id': userId},
    );
    return rows.isNotEmpty;
  }
}

class const ScheduleRecord({
  required final String id,
  required final String vehicleId,
  required final String name,
  required final int intervalMiles,
  required final int intervalMonths,
  required final String details,
}) {
  static ScheduleRecord fromMap(Map<String, dynamic> map) => ScheduleRecord(
    id: map['id'] as String,
    vehicleId: map['vehicle_id'] as String,
    name: map['name'] as String,
    intervalMiles: map['interval_miles'] as int,
    intervalMonths: map['interval_months'] as int,
    details: map['details'] as String,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'vehicle_id': vehicleId,
    'name': name,
    'interval_miles': intervalMiles,
    'interval_months': intervalMonths,
    'details': details,
  };
}
