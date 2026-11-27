import 'package:postgres/postgres.dart';
import 'package:server/src/db/database.dart';
import 'package:server/src/db/duplicate_id.dart';
import 'package:server/src/db/invalid_record.dart';
import 'package:server/src/services/services_dao.dart';
import 'package:shared/model.dart' show MileageUnit;
import 'package:shared/time.dart';

class VehiclesDAO(final ScopedDatabase _database, {final Now _now = DateTime.now}) {
  Future<VehicleRecord> create({
    required String id,
    required String name,
    required CalendarDate manufactureDate,
    required MileageUnit mileageUnit,
  }) async {
    final Result rows;
    try {
      rows = await _database.execute(
        Sql.named('''
INSERT INTO vehicles (id, name, manufacture_date, mileage_unit, created_at, updated_at)
VALUES (@id:uuid, @name:text, @manufacture_date:date, @mileage_unit:text, @now:timestamp, @now:timestamp)
RETURNING id, name, owner_id, manufacture_date, mileage_unit
'''),
        parameters: {
          'id': id,
          'name': name,
          'manufacture_date': manufactureDate.toDateTime(),
          'mileage_unit': mileageUnit.name,
          'now': _now(),
        },
      );
    } on UniqueViolationException {
      throw DuplicateId();
    }
    return VehicleRecord.fromRow(rows.single);
  }

  Future<List<VehicleRecord>> fetchAll() async {
    final rows = await _database.execute(
      Sql.named('''
SELECT vehicle.id, vehicle.name, vehicle.owner_id, vehicle.manufacture_date, vehicle.mileage_unit,
       last_service.id AS last_service_id, last_service.date AS last_service_date,
       last_service.odometer AS last_service_odometer, last_service.details AS last_service_details
FROM vehicles AS vehicle
LEFT JOIN LATERAL (
    SELECT service.id, service.date, service.odometer, service.details
    FROM services AS service
    WHERE service.vehicle_id = vehicle.id
    ORDER BY service.date DESC, service.odometer DESC, service.created_at DESC, service.id DESC
    LIMIT 1
) AS last_service ON TRUE
ORDER BY vehicle.created_at
'''),
    );
    return rows.map(VehicleRecord.fromRow).toList();
  }

  Future<VehicleRecord?> fetchById({required String id}) async {
    final rows = await _database.execute(
      Sql.named('''
SELECT id, name, owner_id, manufacture_date, mileage_unit
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

  Future<bool> existsById({required String id}) async {
    final rows = await _database.execute(
      Sql.named('''
SELECT EXISTS (
  SELECT 1
  FROM vehicles
  WHERE id = @id:uuid
)
'''),
      parameters: {'id': id},
    );
    return rows.single.single as bool;
  }

  Future<VehicleRecord?> update({
    required String id,
    String? name,
    CalendarDate? manufactureDate,
    MileageUnit? mileageUnit,
  }) => _database.runTx((session) async {
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
        parameters: {'id': id, 'manufacture_date': manufactureDate.toDateTime()},
      );
      if (earlierServices.isNotEmpty) throw InvalidRecord();
    }
    final rows = await session.execute(
      Sql.named('''
UPDATE vehicles
SET name = COALESCE(@name:text, name),
    manufacture_date = COALESCE(@manufacture_date:date, manufacture_date),
    mileage_unit = COALESCE(@mileage_unit:text, mileage_unit),
    updated_at = @now:timestamp
WHERE id = @id:uuid
RETURNING id, name, owner_id, manufacture_date, mileage_unit
'''),
      parameters: {
        'id': id,
        'name': name,
        'manufacture_date': manufactureDate?.toDateTime(),
        'mileage_unit': mileageUnit?.name,
        'now': _now(),
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
  required final CalendarDate manufactureDate,
  required final MileageUnit mileageUnit,
  final ServiceRecord? lastService,
}) {
  static VehicleRecord fromRow(ResultRow row) {
    final columns = row.toColumnMap();
    return VehicleRecord(
      id: columns['id'] as String,
      name: columns['name'] as String,
      ownerId: columns['owner_id'] as String,
      manufactureDate: CalendarDate.fromDateTime(columns['manufacture_date'] as DateTime),
      mileageUnit: MileageUnit.values.byName(columns['mileage_unit'] as String),
      lastService: columns['last_service_id'] == null
          ? null
          : ServiceRecord.fromMap({
              'id': columns['last_service_id'],
              'vehicle_id': columns['id'],
              'date': columns['last_service_date'],
              'odometer': columns['last_service_odometer'],
              'details': columns['last_service_details'],
            }),
    );
  }
}

typedef VehiclesTDAOProvider = VehiclesDAO Function(String ownerId);
