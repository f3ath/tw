import 'package:postgres/postgres.dart';
import 'package:server/src/db/database.dart';
import 'package:shared/time.dart';

class ServicesDAO(final ScopedDatabase _database, {final Clock _clock = systemClock}) {
  Future<ServiceRecord?> create({
    required String id,
    required String vehicleId,
    required DateTime date,
    required int odometer,
    required String details,
  }) async {
    final rows = await _database.execute(
      Sql.named('''
INSERT INTO services (id, owner_id, vehicle_id, date, odometer, details, created_at, updated_at)
SELECT @id:uuid, owner_id, id, @date:date, @odometer:int4, @details:text, @now:timestamp, @now:timestamp
FROM vehicles
WHERE id = @vehicle_id:uuid
RETURNING *
'''),
      parameters: {
        'id': id,
        'vehicle_id': vehicleId,
        'date': date,
        'odometer': odometer,
        'details': details,
        'now': _clock(),
      },
    );
    return rows.isEmpty ? null : ServiceRecord.fromMap(rows.single.toColumnMap());
  }

  Future<List<ServiceRecord>> fetchByVehicleId({required String vehicleId}) async {
    final rows = await _database.execute(
      Sql.named('''
SELECT *
FROM services
WHERE vehicle_id = @vehicle_id:uuid
ORDER BY created_at
'''),
      parameters: {'vehicle_id': vehicleId},
    );
    return rows.map((row) => ServiceRecord.fromMap(row.toColumnMap())).toList();
  }

  Future<ServiceRecord?> update({
    required String id,
    required String vehicleId,
    required DateTime date,
    required int odometer,
    String? details,
  }) async {
    final rows = await _database.execute(
      Sql.named('''
UPDATE services
SET date = @date:date,
    odometer = @odometer:int4,
    details = COALESCE(@details:text, details),
    updated_at = @now:timestamp
WHERE id = @id:uuid
  AND vehicle_id = @vehicle_id:uuid
RETURNING *
'''),
      parameters: {
        'id': id,
        'vehicle_id': vehicleId,
        'date': date,
        'odometer': odometer,
        'details': details,
        'now': _clock(),
      },
    );
    return rows.isEmpty ? null : ServiceRecord.fromMap(rows.single.toColumnMap());
  }

  Future<bool> delete({required String id}) async {
    final rows = await _database.execute(
      Sql.named('''
DELETE FROM services
WHERE id = @id:uuid
RETURNING id
'''),
      parameters: {'id': id},
    );
    return rows.isNotEmpty;
  }
}

class const ServiceRecord({
  required final String id,
  required final String vehicleId,
  required final DateTime date,
  required final int odometer,
  required final String details,
}) {
  static ServiceRecord fromMap(Map<String, dynamic> map) => ServiceRecord(
    id: map['id'] as String,
    vehicleId: map['vehicle_id'] as String,
    date: map['date'] as DateTime,
    odometer: map['odometer'] as int,
    details: map['details'] as String,
  );
}

typedef ServicesTDAOProvider = ServicesDAO Function(String ownerId);
