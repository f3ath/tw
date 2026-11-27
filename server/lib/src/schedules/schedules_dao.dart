import 'package:postgres/postgres.dart';
import 'package:server/src/db/database.dart';
import 'package:server/src/db/duplicate_id.dart';
import 'package:server/src/services/services_dao.dart';
import 'package:shared/time.dart';

class SchedulesDAO(final Database _database, {final Now _now = DateTime.now}) {
  Future<ScheduleRecord?> create({
    required String id,
    required String vehicleId,
    required String name,
    required int? intervalDistance,
    required int? intervalMonths,
    required String details,
    bool isArchived = false,
  }) async {
    final Result rows;
    try {
      rows = await _database.execute(
        Sql.named('''
INSERT INTO schedules (id, vehicle_id, name, interval_distance, interval_months, details, is_archived, created_at, updated_at)
SELECT @id:uuid, id, @name:text, @interval_distance:int4, @interval_months:int4, @details:text, @is_archived:boolean, @now:timestamp, @now:timestamp
FROM vehicles
WHERE id = @vehicle_id:uuid
RETURNING id, vehicle_id, name, interval_distance, interval_months, details, is_archived
'''),
        parameters: {
          'id': id,
          'vehicle_id': vehicleId,
          'name': name,
          'interval_distance': intervalDistance,
          'interval_months': intervalMonths,
          'details': details,
          'is_archived': isArchived,
          'now': _now(),
        },
      );
    } on UniqueViolationException {
      throw DuplicateId();
    }
    return rows.isEmpty ? null : ScheduleRecord.fromMap(rows.single.toColumnMap());
  }

  Future<List<ScheduleRecord>> fetchByVehicleId({required String vehicleId}) async {
    final rows = await _database.execute(
      Sql.named('''
SELECT schedule.id, schedule.vehicle_id, schedule.name, schedule.interval_distance,
       schedule.interval_months, schedule.details, schedule.is_archived,
       performed.id AS performed_id, performed.vehicle_id AS performed_vehicle_id,
       performed.date AS performed_date,
       performed.odometer AS performed_odometer, performed.details AS performed_details
FROM schedules AS schedule
LEFT JOIN LATERAL (
    SELECT service.id, service.vehicle_id, service.date, service.odometer, service.details
    FROM service_operations AS operation
    JOIN services AS service ON service.id = operation.service_id
    WHERE operation.schedule_id = schedule.id
    ORDER BY service.date DESC, service.odometer DESC, service.created_at DESC, service.id DESC
    LIMIT 1
) AS performed ON TRUE
WHERE schedule.vehicle_id = @vehicle_id:uuid
ORDER BY schedule.created_at
'''),
      parameters: {'vehicle_id': vehicleId},
    );
    return rows.map((row) => ScheduleRecord.fromMap(row.toColumnMap())).toList();
  }

  Future<ScheduleRecord?> fetchById({required String id}) async {
    final rows = await _database.execute(
      Sql.named('''
SELECT id, vehicle_id, name, interval_distance, interval_months, details, is_archived
FROM schedules
WHERE id = @id:uuid
'''),
      parameters: {'id': id},
    );
    return rows.isEmpty ? null : ScheduleRecord.fromMap(rows.single.toColumnMap());
  }

  Future<List<ScheduleRecord>> fetchAll() async {
    final rows = await _database.execute(
      Sql.named('''
SELECT id, vehicle_id, name, interval_distance, interval_months, details, is_archived
FROM schedules
ORDER BY created_at
'''),
    );
    return rows.map((row) => ScheduleRecord.fromMap(row.toColumnMap())).toList();
  }

  Future<ScheduleRecord?> update({
    required String id,
    required String name,
    required int? intervalDistance,
    required int? intervalMonths,
    required String details,
    required bool isArchived,
  }) async {
    final rows = await _database.execute(
      Sql.named('''
UPDATE schedules
SET name = @name:text,
    interval_distance = @interval_distance:int4,
    interval_months = @interval_months:int4,
    details = @details:text,
    is_archived = @is_archived:boolean,
    updated_at = @now:timestamp
WHERE id = @id:uuid
RETURNING id, vehicle_id, name, interval_distance, interval_months, details, is_archived
'''),
      parameters: {
        'id': id,
        'name': name,
        'interval_distance': intervalDistance,
        'interval_months': intervalMonths,
        'details': details,
        'is_archived': isArchived,
        'now': _now(),
      },
    );
    if (rows.isEmpty) {
      return null;
    }
    return ScheduleRecord.fromMap(rows.single.toColumnMap());
  }

  Future<bool> delete({required String id}) async {
    final rows = await _database.execute(
      Sql.named('''
DELETE FROM schedules
WHERE id = @id:uuid
RETURNING id
'''),
      parameters: {'id': id},
    );
    return rows.isNotEmpty;
  }
}

class const ScheduleRecord({
  required final String id,
  required final String vehicleId,
  required final String name,
  required final int? intervalDistance,
  required final int? intervalMonths,
  required final String details,
  final bool isArchived = false,
  final ServiceRecord? lastPerformed,
}) {
  static ScheduleRecord fromMap(Map<String, dynamic> map) => ScheduleRecord(
    id: map['id'] as String,
    vehicleId: map['vehicle_id'] as String,
    name: map['name'] as String,
    intervalDistance: map['interval_distance'] as int?,
    intervalMonths: map['interval_months'] as int?,
    details: map['details'] as String,
    isArchived: map['is_archived'] as bool,
    lastPerformed: map['performed_id'] == null
        ? null
        : ServiceRecord.fromMap(map, prefix: 'performed_'),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'vehicle_id': vehicleId,
    'name': name,
    'interval_distance': intervalDistance,
    'interval_months': intervalMonths,
    'details': details,
    'is_archived': isArchived,
  };
}

typedef SchedulesTDAOProvider = SchedulesDAO Function(String ownerId);
