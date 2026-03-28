import 'package:powersync/powersync.dart';

extension PowerSyncUpsert on PowerSyncDatabase {
  /// Inserts a row or updates it on conflict using DELETE + INSERT in a
  /// write transaction.
  ///
  /// PowerSync exposes all tables (synced and local-only) as SQLite views with
  /// INSTEAD OF triggers. SQLite does not support `INSERT ON CONFLICT DO UPDATE`
  /// on views, so this falls back to DELETE + INSERT which the triggers handle.
  ///
  /// [values] maps column names to values for the full INSERT.
  /// [idColumn] is the primary key column used to identify the existing row.
  Future<void> upsert(
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
