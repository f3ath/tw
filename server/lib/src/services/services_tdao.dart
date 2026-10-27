import 'package:postgres/postgres.dart';
import 'package:server/src/db/database.dart';
import 'package:shared/time.dart';

class ServicesTDAO(final ScopedDatabase _database, {final Clock _clock = systemClock}) {
  Future<ServiceRecord?> create({
    required String id,
    required String vehicleId,
    required DateTime date,
    required int mileage,
    required String details,
  }) async {
    final rows = await _database.execute(
      Sql.named('''
INSERT INTO services (id, owner_id, vehicle_id, date, mileage, details, created_at, updated_at)
SELECT @id:uuid, owner_id, id, @date:date, @mileage:int4, @details:text, @now:timestamp, @now:timestamp
FROM vehicles
WHERE id = @vehicle_id:uuid
RETURNING id, vehicle_id, date, mileage, details
'''),
      parameters: {
        'id': id,
        'vehicle_id': vehicleId,
        'date': date,
        'mileage': mileage,
        'details': details,
        'now': _clock(),
      },
    );
    return rows.isEmpty ? null : ServiceRecord.fromRow(rows.single);
  }

  Future<List<ServiceRecord>> fetchByVehicleId({required String vehicleId}) async {
    final rows = await _database.execute(
      Sql.named('''
SELECT id, vehicle_id, date, mileage, details
FROM services
WHERE vehicle_id = @vehicle_id:uuid
ORDER BY created_at
'''),
      parameters: {'vehicle_id': vehicleId},
    );
    return rows.map(ServiceRecord.fromRow).toList();
  }

  Future<ServiceRecord?> update({
    required String id,
    required String vehicleId,
    required DateTime date,
    required int mileage,
    String? details,
  }) async {
    final rows = await _database.execute(
      Sql.named('''
UPDATE services
SET date = @date:date,
    mileage = @mileage:int4,
    details = COALESCE(@details:text, details),
    updated_at = @now:timestamp
WHERE id = @id:uuid
  AND vehicle_id = @vehicle_id:uuid
RETURNING id, vehicle_id, date, mileage, details
'''),
      parameters: {
        'id': id,
        'vehicle_id': vehicleId,
        'date': date,
        'mileage': mileage,
        'details': details,
        'now': _clock(),
      },
    );
    return rows.isEmpty ? null : ServiceRecord.fromRow(rows.single);
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
  required final int mileage,
  required final String details,
}) {
  static ServiceRecord fromRow(ResultRow row) => ServiceRecord(
    id: row[0] as String,
    vehicleId: row[1] as String,
    date: row[2] as DateTime,
    mileage: row[3] as int,
    details: row[4] as String,
  );
}

typedef ServicesTDAOProvider = ServicesTDAO Function(String ownerId);
