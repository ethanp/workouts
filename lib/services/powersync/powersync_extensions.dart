import 'package:powersync/powersync.dart';

extension PowerSyncUpsert on PowerSyncDatabase {
  /// Inserts a row or updates it in place if a row with the same [idColumn] already exists.
  ///
  /// Uses INSERT for new rows and UPDATE for existing rows so that PowerSync's
  /// sync layer records the correct operation type. DELETE + INSERT would
  /// generate separate oplog entries that allow an incoming server sync to
  /// overwrite the local change before it is uploaded.
  Future<void> upsert(
    String table,
    Map<String, Object?> values, {
    String idColumn = 'id',
  }) async {
    final existingRow = await getOptional(
      'SELECT $idColumn FROM $table WHERE $idColumn = ?',
      [values[idColumn]],
    );
    if (existingRow != null) {
      final updateColumns = values.keys
          .where((col) => col != idColumn)
          .toList();
      final setClause = updateColumns.map((col) => '$col = ?').join(', ');
      await execute('UPDATE $table SET $setClause WHERE $idColumn = ?', [
        ...updateColumns.map((col) => values[col]),
        values[idColumn],
      ]);
    } else {
      final columns = values.keys.toList();
      final placeholders = columns.map((_) => '?').join(', ');
      await execute(
        'INSERT INTO $table (${columns.join(', ')}) VALUES ($placeholders)',
        values.values.toList(),
      );
    }
  }
}
