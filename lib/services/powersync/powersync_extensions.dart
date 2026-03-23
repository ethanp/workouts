import 'package:powersync/powersync.dart';

extension PowerSyncUpsert on PowerSyncDatabase {
  /// Inserts a row or updates it on conflict, using `ON CONFLICT DO UPDATE`.
  ///
  /// [values] maps column names to values for the full INSERT.
  /// [conflictColumns] identifies the unique constraint to match on.
  /// [updateColumns] controls which columns are updated on conflict;
  /// defaults to all non-conflict columns.
  Future<void> upsert(
    String table,
    Map<String, Object?> values, {
    List<String> conflictColumns = const ['id'],
    List<String>? updateColumns,
  }) async {
    final columns = values.keys.toList();
    final placeholders = columns.map((_) => '?').join(', ');
    final toUpdate = updateColumns ??
        columns
            .where(
              (columnName) => !conflictColumns.contains(columnName),
            )
            .toList();
    final updateSet = toUpdate
        .map((columnName) => '$columnName = excluded.$columnName')
        .join(', ');
    await execute(
      'INSERT INTO $table (${columns.join(', ')}) VALUES ($placeholders)'
      ' ON CONFLICT(${conflictColumns.join(', ')}) DO UPDATE SET $updateSet',
      values.values.toList(),
    );
  }

  /// Upserts into a local-only (view-backed) table using DELETE + INSERT.
  ///
  /// PowerSync exposes `Table.localOnly` tables as SQLite views. SQLite does
  /// not support `INSERT ON CONFLICT DO UPDATE` on views, so this method falls
  /// back to a DELETE + INSERT wrapped in a write transaction.
  Future<void> upsertLocalOnly(
    String table,
    Map<String, Object?> values, {
    String idColumn = 'id',
  }) {
    return writeTransaction((transaction) async {
      await transaction.execute(
        'DELETE FROM $table WHERE $idColumn = ?',
        [values[idColumn]],
      );
      final columns = values.keys.toList();
      final placeholders = columns.map((_) => '?').join(', ');
      await transaction.execute(
        'INSERT INTO $table (${columns.join(', ')}) VALUES ($placeholders)',
        values.values.toList(),
      );
    });
  }
}
