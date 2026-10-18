import 'package:postgres/postgres.dart';

class Database(final Connection _connection) {
  Future<Result> execute(
    Object query, {
    Object? parameters,
    bool ignoreRows = false,
    QueryMode? queryMode,
    Duration? timeout,
  }) => _connection.runTx((session) {
    return session.execute(
      query,
      parameters: parameters,
      ignoreRows: ignoreRows,
      queryMode: queryMode,
      timeout: timeout,
    );
  });
}

class ScopedDatabase(final String _userId, super.connection) extends Database {
  @override
  Future<Result> execute(
    Object query, {
    Object? parameters,
    bool ignoreRows = false,
    QueryMode? queryMode,
    Duration? timeout,
  }) => _connection.runTx((session) async {
    // await session.execute(
    //   Sql.named("SELECT set_config('tw.tenant_id', @id:text,true)"),
    // );
    return await session.execute(
      query,
      parameters: parameters,
      ignoreRows: ignoreRows,
      queryMode: queryMode,
      timeout: timeout,
    );
  });
}
