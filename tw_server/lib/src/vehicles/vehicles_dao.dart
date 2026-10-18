import 'package:postgres/postgres.dart';
import 'package:tw_server/src/time/clock.dart';

class VehiclesDAO(final Connection connection, {Clock clock = defaultClock}) {
  final _clock = clock;
  Future<VehicleRecord> create({
    required String id,
    required String name,
    required String userId,
    required DateTime manufactureDate,
  }) async {
    final vehicle = VehicleRecord(
      id: id,
      name: name,
      ownerId: userId,
      manufactureDate: manufactureDate,
    );
    final now = _clock();
    await connection.execute(
      Sql.named('''
INSERT INTO vehicles (id, name, owner_id, manufacture_date, created_at, updated_at)
VALUES (@id:text, @name:text, @owner_id:text, @manufacture_date:date, @now:timestamp, @now:timestamp)
'''),
      parameters: {...vehicle.toMap(), 'now': now},
    );
    return vehicle;
  }

  Future<List<VehicleRecord>> fetchByUserId(String userId) async {
    final rows = await connection.execute(
      Sql.named('''
SELECT id, name, owner_id, manufacture_date
FROM vehicles
WHERE owner_id = @owner_id:text
ORDER BY created_at
'''),
      parameters: {'owner_id': userId},
    );
    return rows.map((row) => VehicleRecord.fromMap(row.toColumnMap())).toList();
  }

  Future<VehicleRecord?> fetchByIdAndUserId({required String id, required String userId}) async {
    final rows = await connection.execute(
      Sql.named('''
SELECT id, name, owner_id, manufacture_date
FROM vehicles
WHERE id = @id:text AND owner_id = @owner_id:text
'''),
      parameters: {'id': id, 'owner_id': userId},
    );
    if (rows.isEmpty) {
      return null;
    }
    return VehicleRecord.fromMap(rows.single.toColumnMap());
  }

  Future<VehicleRecord?> update({
    required String id,
    required String userId,
    String? name,
    DateTime? manufactureDate,
  }) async {
    final rows = await connection.execute(
      Sql.named('''
UPDATE vehicles
SET name = COALESCE(@name:text, name),
    manufacture_date = COALESCE(@manufacture_date:date, manufacture_date),
    updated_at = @now:timestamp
WHERE id = @id:text AND owner_id = @owner_id:text
RETURNING id, name, owner_id, manufacture_date
'''),
      parameters: {
        'id': id,
        'owner_id': userId,
        'name': name,
        'manufacture_date': manufactureDate,
        'now': _clock(),
      },
    );
    if (rows.isEmpty) {
      return null;
    }
    return VehicleRecord.fromMap(rows.single.toColumnMap());
  }

  Future<bool> delete({required String id, required String userId}) async {
    final rows = await connection.execute(
      Sql.named('''
DELETE FROM vehicles
WHERE id = @id:text AND owner_id = @owner_id:text
RETURNING id
'''),
      parameters: {'id': id, 'owner_id': userId},
    );
    return rows.isNotEmpty;
  }
}

class const VehicleRecord({
  required final String id,
  required final String name,
  required final String ownerId,
  required final DateTime manufactureDate,
}) {
  static VehicleRecord fromMap(Map<String, dynamic> map) => VehicleRecord(
    id: map['id'] as String,
    name: map['name'] as String,
    ownerId: map['owner_id'] as String,
    manufactureDate: map['manufacture_date'] as DateTime,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'owner_id': ownerId,
    'manufacture_date': manufactureDate,
  };
}
