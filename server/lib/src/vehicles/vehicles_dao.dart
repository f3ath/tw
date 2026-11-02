import 'package:postgres/postgres.dart';
import 'package:server/src/db/database.dart';
import 'package:server/src/db/invalid_record.dart';
import 'package:shared/time.dart';
import 'package:shared/api.dart' show DistanceUnit;

class VehiclesDAO(final ScopedDatabase _database, {final Clock _clock = systemClock}) {
  Future<VehicleRecord> create({
    required String id,
    required String name,
    required DateTime manufactureDate,
    required DistanceUnit distanceUnit,
  }) async {
    final rows = await _database.execute(
      Sql.named('''
INSERT INTO vehicles (id, name, manufacture_date, distance_unit, created_at, updated_at)
VALUES (@id:uuid, @name:text, @manufacture_date:date, @distance_unit:text, @now:timestamp, @now:timestamp)
RETURNING id, name, owner_id, manufacture_date, distance_unit
'''),
      parameters: {
        'id': id,
        'name': name,
        'manufacture_date': manufactureDate,
        'distance_unit': distanceUnit.name,
        'now': _clock(),
      },
    );
    return VehicleRecord.fromRow(rows.single);
  }

  Future<List<VehicleRecord>> fetchAll() async {
    final rows = await _database.execute(
      Sql.named('''
SELECT id, name, owner_id, manufacture_date, distance_unit
FROM vehicles
ORDER BY created_at
'''),
    );
    return rows.map(VehicleRecord.fromRow).toList();
  }

  Future<VehicleRecord?> fetchById({required String id}) async {
    final rows = await _database.execute(
      Sql.named('''
SELECT id, name, owner_id, manufacture_date, distance_unit
FROM vehicles
WHERE id = @id:uuid
'''),
      parameters: {'id': id},
    );
    if (rows.isEmpty) {
      return null;
    }
    return VehicleRecord.fromRow(rows.single);
  }

  Future<VehicleRecord?> update({required String id, String? name, DateTime? manufactureDate}) =>
      _database.runTx((session) async {
        final vehicles = await session.execute(
          Sql.named('''
SELECT id
FROM vehicles
WHERE id = @id:uuid
FOR UPDATE
'''),
          parameters: {'id': id},
        );
        if (vehicles.isEmpty) return null;
        if (manufactureDate != null) {
          final earlierServices = await session.execute(
            Sql.named('''
SELECT id
FROM services
WHERE vehicle_id = @id:uuid
  AND date < @manufacture_date:date
LIMIT 1
'''),
            parameters: {'id': id, 'manufacture_date': manufactureDate},
          );
          if (earlierServices.isNotEmpty) throw InvalidRecord();
        }
        final rows = await session.execute(
          Sql.named('''
UPDATE vehicles
SET name = COALESCE(@name:text, name),
    manufacture_date = COALESCE(@manufacture_date:date, manufacture_date),
    updated_at = @now:timestamp
WHERE id = @id:uuid
RETURNING id, name, owner_id, manufacture_date, distance_unit
'''),
          parameters: {
            'id': id,
            'name': name,
            'manufacture_date': manufactureDate,
            'now': _clock(),
          },
        );
        if (rows.isEmpty) {
          return null;
        }
        return VehicleRecord.fromRow(rows.single);
      });

  Future<bool> delete({required String id}) async {
    final result = await _database.execute(
      Sql.named('''
DELETE FROM vehicles
WHERE id = @id:uuid
'''),
      parameters: {'id': id},
      ignoreRows: true,
    );
    return result.affectedRows > 0;
  }
}

class const VehicleRecord({
  required final String id,
  required final String name,
  required final String ownerId,
  required final DateTime manufactureDate,
  required final DistanceUnit distanceUnit,
}) {
  static VehicleRecord fromRow(ResultRow row) => VehicleRecord(
    id: row[0] as String,
    name: row[1] as String,
    ownerId: row[2] as String,
    manufactureDate: dateOnly(row[3] as DateTime),
    distanceUnit: DistanceUnit.values.byName(row[4] as String),
  );
}

typedef VehiclesTDAOProvider = VehiclesDAO Function(String ownerId);
