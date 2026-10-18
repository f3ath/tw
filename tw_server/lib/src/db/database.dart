import 'package:postgres/postgres.dart';

class Database(final Connection _connection) {
  Future<Result> execute(
    Object query, {
    Object? parameters,
    bool ignoreRows = false,
    QueryMode? queryMode,
    Duration? timeout,
  }) => _connection.execute(
      query,
      parameters: parameters,
      ignoreRows: ignoreRows,
      queryMode: queryMode,
      timeout: timeout,
  );
}
