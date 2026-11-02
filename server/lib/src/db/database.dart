import 'package:postgres/postgres.dart';

class Database(final Connection _connection) {
  Future<T> runTx<T>(Future<T> Function(TxSession session) action) => _connection.runTx(action);

  Future<Result> execute(
    Object query, {
    Object? parameters,
    bool ignoreRows = false,
    QueryMode? queryMode,
    Duration? timeout,
  }) => runTx(
    (session) => session.execute(
      query,
      parameters: parameters,
      ignoreRows: ignoreRows,
      queryMode: queryMode,
      timeout: timeout,
    ),
  );
}

class ScopedDatabase(final String _tenantId, super.connection) extends Database {
  @override
  Future<T> runTx<T>(Future<T> Function(TxSession session) action) =>
      _connection.runTx((session) async {
        await session.execute(
          Sql.named('''
SELECT set_config('tw.tenant_id', @tenant_id::uuid::text, true)
'''),
          parameters: {'tenant_id': _tenantId},
        );
        return action(session);
      });
}
