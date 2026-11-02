import 'package:postgres/postgres.dart';
import 'package:server/src/db/database.dart';
import 'package:server/src/db/invalid_record.dart';
import 'package:shared/time.dart';

class ServicesDAO(final ScopedDatabase _database, {final Clock _clock = systemClock}) {
  Future<ServiceRecord?> create({
    required String id,
    required String vehicleId,
    required DateTime date,
    required int odometer,
    required String details,
  }) => _database.runTx((session) async {
    if (!await _validate(session, vehicleId: vehicleId, date: date, odometer: odometer)) {
      return null;
    }
    final rows = await session.execute(
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
  });

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
    required DateTime date,
    required int odometer,
    String? details,
  }) => _database.runTx((session) async {
    final existing = await session.execute(
      Sql.named('''
SELECT vehicle_id
FROM services
WHERE id = @id:uuid
'''),
      parameters: {'id': id},
    );
    if (existing.isEmpty) return null;
    final vehicleId = existing.single[0] as String;
    if (!await _validate(
      session,
      vehicleId: vehicleId,
      date: date,
      odometer: odometer,
      excludeId: id,
    )) {
      return null;
    }
    final rows = await session.execute(
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
  });

  Future<bool> _validate(
    TxSession session, {
    required String vehicleId,
    required DateTime date,
    required int odometer,
    String? excludeId,
  }) async {
    final vehicles = await session.execute(
      Sql.named('''
SELECT manufacture_date
FROM vehicles
WHERE id = @vehicle_id:uuid
FOR UPDATE
'''),
      parameters: {'vehicle_id': vehicleId},
    );
    if (vehicles.isEmpty) return false;
    final manufactured = vehicles.single[0] as DateTime;
    if (dateOnly(date).isBefore(dateOnly(manufactured))) {
      throw InvalidRecord();
    }
    final invalidNeighbors = await session.execute(
      Sql.named('''
SELECT id
FROM services
WHERE vehicle_id = @vehicle_id:uuid
  AND id IS DISTINCT FROM @exclude_id:uuid
  AND ((date < @date:date AND odometer > @odometer:int4)
    OR (date > @date:date AND odometer < @odometer:int4))
LIMIT 1
'''),
      parameters: {
        'vehicle_id': vehicleId,
        'exclude_id': excludeId,
        'date': date,
        'odometer': odometer,
      },
    );
    if (invalidNeighbors.isNotEmpty) throw InvalidRecord();
    return true;
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
    date: dateOnly(map['date'] as DateTime),
    odometer: map['odometer'] as int,
    details: map['details'] as String,
  );
}

typedef ServicesTDAOProvider = ServicesDAO Function(String ownerId);
