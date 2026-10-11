import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

class VehiclesDAO(final Connection connection) {
  static const _uuid = Uuid();

  Future<VehicleRecord> create({
    required String name,
    required String userId,
    required DateTime manufactureDate,
  }) async {
    final vehicle = VehicleRecord(
      id: _uuid.v4(),
      name: name,
      userId: userId,
      manufactureDate: manufactureDate,
    );
    await connection.execute(
      Sql.named('''
INSERT INTO vehicles (id, name, user_id, manufacture_date)
VALUES (@id:text, @name:text, @user_id:text, @manufacture_date:date)
'''),
      parameters: vehicle.toMap(),
    );
    return vehicle;
  }

  Future<List<VehicleRecord>> fetchByUserId(String userId) async {
    final rows = await connection.execute(
      Sql.named('''
SELECT id, name, user_id, manufacture_date
FROM vehicles
WHERE user_id = @user_id:text
ORDER BY created_at
'''),
      parameters: {'user_id': userId},
    );
    return rows.map((row) => VehicleRecord.fromMap(row.toColumnMap())).toList();
  }

  Future<VehicleRecord?> fetchByIdAndUserId({required String id, required String userId}) async {
    final rows = await connection.execute(
      Sql.named('''
SELECT id, name, user_id, manufacture_date
FROM vehicles
WHERE id = @id:text AND user_id = @user_id:text
'''),
      parameters: {'id': id, 'user_id': userId},
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
    manufacture_date = COALESCE(@manufacture_date:date, manufacture_date)
WHERE id = @id:text AND user_id = @user_id:text
RETURNING id, name, user_id, manufacture_date
'''),
      parameters: {'id': id, 'user_id': userId, 'name': name, 'manufacture_date': manufactureDate},
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
WHERE id = @id:text AND user_id = @user_id:text
RETURNING id
'''),
      parameters: {'id': id, 'user_id': userId},
    );
    return rows.isNotEmpty;
  }
}

class const VehicleRecord({
  required final String id,
  required final String name,
  required final String userId,
  required final DateTime manufactureDate,
}) {
  static VehicleRecord fromMap(Map<String, dynamic> map) => VehicleRecord(
    id: map['id'] as String,
    name: map['name'] as String,
    userId: map['user_id'] as String,
    manufactureDate: map['manufacture_date'] as DateTime,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'user_id': userId,
    'manufacture_date': manufactureDate,
  };
}
