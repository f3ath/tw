import 'package:postgres/postgres.dart';
import 'package:server/src/db/database.dart';
import 'package:server/src/db/duplicate_id.dart';
import 'package:server/src/db/invalid_record.dart';
import 'package:shared/time.dart';

class OperationsDAO(final ScopedDatabase _database, {final Now _now = DateTime.now}) {
  static const _select = '''
SELECT operation.id, operation.service_id, operation.schedule_id,
       operation.name, operation.details
FROM service_operations AS operation
''';

  Future<List<OperationRecord>?> fetchByServiceId(String serviceId) =>
      _database.runTx((session) async {
        final services = await session.execute(
          Sql.named('''
SELECT id
FROM services
WHERE id = @service_id:uuid
'''),
          parameters: {'service_id': serviceId},
        );
        if (services.isEmpty) return null;
        final rows = await session.execute(
          Sql.named('''
$_select
WHERE operation.service_id = @service_id:uuid
ORDER BY operation.created_at, operation.id
'''),
          parameters: {'service_id': serviceId},
        );
        return rows.map((row) => OperationRecord.fromMap(row.toColumnMap())).toList();
      });

  Future<List<OperationRecord>> fetchByServiceIds(List<String> serviceIds) async {
    if (serviceIds.isEmpty) return [];
    final rows = await _database.execute(
      Sql.named('''
$_select
WHERE operation.service_id = ANY(@service_ids:_uuid)
ORDER BY operation.created_at, operation.id
'''),
      parameters: {'service_ids': serviceIds},
    );
    return rows.map((row) => OperationRecord.fromMap(row.toColumnMap())).toList();
  }

  Future<OperationRecord?> fetchById(String id) =>
      _database.runTx((session) => _fetchById(session, id));

  Future<OperationRecord?> create({
    required String id,
    required String serviceId,
    String? scheduleId,
    String? name,
    String? details,
  }) => _database.runTx((session) async {
    final vehicleId = await _lockService(session, serviceId);
    if (vehicleId == null) return null;
    await _validateSchedule(
      session,
      operationId: id,
      serviceId: serviceId,
      vehicleId: vehicleId,
      scheduleId: scheduleId,
    );
    String? resolvedName = name;
    if (resolvedName == null && scheduleId != null) {
      final rows = await session.execute(
        Sql.named('''
SELECT name
FROM schedules
WHERE id = @schedule_id:uuid
'''),
        parameters: {'schedule_id': scheduleId},
      );
      resolvedName = rows.single[0] as String;
    }
    try {
      await session.execute(
        Sql.named('''
INSERT INTO service_operations (id, owner_id, vehicle_id, service_id, schedule_id, name, details, created_at, updated_at)
SELECT @id:uuid, owner_id, vehicle_id, id, @schedule_id:uuid, @name:text, @details:text, @now:timestamp, @now:timestamp
FROM services
WHERE id = @service_id:uuid
'''),
        parameters: {
          'id': id,
          'service_id': serviceId,
          'schedule_id': scheduleId,
          'name': resolvedName,
          'details': details ?? '',
          'now': _now(),
        },
      );
    } on UniqueViolationException {
      throw DuplicateId();
    }
    return _fetchById(session, id);
  });

  Future<OperationRecord?> update({
    required String id,
    String? scheduleId,
    String? name,
    String? details,
  }) => _database.runTx((session) async {
    final original = await _fetchById(session, id);
    if (original == null) return null;
    final serviceId = original.serviceId;
    final vehicleId = await _lockService(session, serviceId);
    if (vehicleId == null) return null;
    final existing = await _fetchById(session, id);
    if (existing == null) return null;
    await _validateSchedule(
      session,
      operationId: id,
      serviceId: serviceId,
      vehicleId: vehicleId,
      scheduleId: scheduleId,
      previousScheduleId: existing.scheduleId,
    );
    await session.execute(
      Sql.named('''
UPDATE service_operations
SET schedule_id = @schedule_id:uuid,
    name = COALESCE(@name:text, name),
    details = COALESCE(@details:text, details),
    updated_at = @now:timestamp
WHERE id = @id:uuid
  AND service_id = @service_id:uuid
'''),
      parameters: {
        'id': id,
        'service_id': serviceId,
        'schedule_id': scheduleId,
        'name': name,
        'details': details,
        'now': _now(),
      },
    );
    return _fetchById(session, id);
  });

  Future<bool> delete(String id) async {
    final rows = await _database.execute(
      Sql.named('''
DELETE FROM service_operations
WHERE id = @id:uuid
RETURNING id
'''),
      parameters: {'id': id},
    );
    return rows.isNotEmpty;
  }

  Future<String?> _lockService(TxSession session, String serviceId) async {
    final rows = await session.execute(
      Sql.named('''
SELECT vehicle_id
FROM services
WHERE id = @service_id:uuid
FOR UPDATE
'''),
      parameters: {'service_id': serviceId},
    );
    return rows.isEmpty ? null : rows.single[0] as String;
  }

  Future<void> _validateSchedule(
    TxSession session, {
    required String operationId,
    required String serviceId,
    required String vehicleId,
    required String? scheduleId,
    String? previousScheduleId,
  }) async {
    if (scheduleId == null) return;
    final schedules = await session.execute(
      Sql.named('''
SELECT vehicle_id, is_archived
FROM schedules
WHERE id = @schedule_id:uuid
FOR SHARE
'''),
      parameters: {'schedule_id': scheduleId},
    );
    if (schedules.isEmpty) throw InvalidRecord();
    final schedule = schedules.single;
    if (schedule[0] != vehicleId || schedule[1] == true && previousScheduleId != scheduleId) {
      throw InvalidRecord();
    }
    final duplicates = await session.execute(
      Sql.named('''
SELECT id
FROM service_operations
WHERE service_id = @service_id:uuid
  AND schedule_id = @schedule_id:uuid
  AND id <> @operation_id:uuid
LIMIT 1
'''),
      parameters: {'service_id': serviceId, 'schedule_id': scheduleId, 'operation_id': operationId},
    );
    if (duplicates.isNotEmpty) throw InvalidRecord();
  }

  Future<OperationRecord?> _fetchById(TxSession session, String id) async {
    final rows = await session.execute(
      Sql.named('''
$_select
WHERE operation.id = @id:uuid
'''),
      parameters: {'id': id},
    );
    return rows.isEmpty ? null : OperationRecord.fromMap(rows.single.toColumnMap());
  }
}

class const OperationRecord({
  required final String id,
  required final String serviceId,
  required final String name,
  required final String details,
  final String? scheduleId,
}) {
  static OperationRecord fromMap(Map<String, dynamic> map) => OperationRecord(
    id: map['id'] as String,
    serviceId: map['service_id'] as String,
    name: map['name'] as String,
    details: map['details'] as String,
    scheduleId: map['schedule_id'] as String?,
  );
}

typedef OperationsDAOProvider = OperationsDAO Function(String ownerId);
