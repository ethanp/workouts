import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:powersync/powersync.dart';
import 'package:workouts/utils/error_bus.dart';

final _log = Logger('PostgRestUploader');

class PostgRestUploader {
  PostgRestUploader(this._baseUrl);

  final String _baseUrl;

  // Tables that have FK dependencies — if the parent row is gone from the
  // server, we discard the child op rather than retrying forever.
  static const _childTables = {
    'run_route_points',
    'run_heart_rate_samples',
    'workout_blocks',
    'workout_block_exercises',
    'session_blocks',
    'session_block_exercises',
    'session_set_logs',
    'session_notes',
    'background_notes',
    'heart_rate_samples',
  };

  // Non-PK unique constraints PostgREST needs for on_conflict merge-duplicates.
  // Tables not listed here fall back to the primary key (id).
  // Must match the UNIQUE constraints in init.sql.
  // exercises is deliberately excluded — see _handleExerciseConflict.
  static const _conflictColumns = {
    'workout_blocks': 'template_id,block_index',
    'workout_block_exercises': 'block_id,exercise_id,exercise_index',
    'session_blocks': 'session_id,block_index',
    'session_block_exercises': 'block_id,exercise_id,exercise_index',
    'session_set_logs': 'block_id,exercise_id,set_index',
    'run_route_points': 'run_id,point_index',
    'run_heart_rate_samples': 'run_id,timestamp',
  };

  /// Returns true if the entry was discarded rather than uploaded.
  Future<bool> upload(CrudEntry op, http.Client client) async {
    try {
      switch (op.op) {
        case UpdateType.put:
          return await _put(op, client);
        case UpdateType.patch:
          await _patch(op, client);
        case UpdateType.delete:
          await _delete(op, client);
      }
      return false;
    } catch (e) {
      _log.severe('Upload error for ${op.table} ${op.id}: $e');
      errorBus.add('Upload ${op.table} ${op.op.name}: $e');
      rethrow;
    }
  }

  /// Upserts a row via PostgREST POST with `Prefer: resolution=merge-duplicates`,
  /// which translates to `INSERT ... ON CONFLICT DO UPDATE`.
  ///
  /// Upsert (rather than plain INSERT) is necessary because PowerSync's CRUD
  /// queue may replay ops after network failures or ambiguous timeouts — the
  /// row might already exist server-side from a previous attempt that succeeded
  /// but wasn't acknowledged locally. Upsert makes every op idempotent.
  ///
  /// For tables with non-PK unique constraints (see [_conflictColumns]), we
  /// must pass `on_conflict` so PostgREST knows which constraint to merge on.
  /// Without it, PostgREST defaults to the PK and returns 409 when the
  /// secondary unique constraint fires.
  Future<bool> _put(CrudEntry op, http.Client client) async {
    final table = op.table;
    final data = op.opData;
    final conflictColumns = _conflictColumns[table];
    final url = conflictColumns != null
        ? '$_baseUrl/$table?on_conflict=$conflictColumns'
        : '$_baseUrl/$table';

    final response = await client.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Prefer': 'resolution=merge-duplicates',
      },
      body: jsonEncode({...?data, 'id': op.id}),
    );

    if (response.statusCode == 409) {
      return _handleConflict(op, data, response.body, client);
    }
    _requireOk(response, 'PUT');
    return false;
  }

  /// Resolves 409 conflicts: retries duplicate runs after deleting the old UUID,
  /// discards orphaned child rows whose parent run no longer exists.
  Future<bool> _handleConflict(
    CrudEntry op,
    Map<String, dynamic>? data,
    String responseBody,
    http.Client client,
  ) async {
    final table = op.table;

    // Exercise name already exists under a different ID (happens after app
    // reinstall — new UUIDs, same names). We can't change the server's ID
    // because other tables (workout_block_exercises) hold FK references to it.
    // Instead, PATCH the existing row by name without touching its ID.
    if (responseBody.contains('"23505"') && table == 'exercises') {
      return _patchExerciseByName(data, client);
    }
    if (responseBody.contains('"23503"') && table == 'exercises') {
      return _patchExerciseByName(data, client);
    }

    if (responseBody.contains('"23505"') && table == 'runs') {
      final externalId = data?['external_workout_id'] as String?;
      if (externalId != null) {
        await client.delete(
          Uri.parse(
            '$_baseUrl/$table?external_workout_id=eq.$externalId',
          ),
          headers: {'Content-Type': 'application/json'},
        );
        final retryResponse = await client.post(
          Uri.parse('$_baseUrl/$table'),
          headers: {
            'Content-Type': 'application/json',
            'Prefer': 'resolution=merge-duplicates',
          },
          body: jsonEncode({...?data, 'id': op.id}),
        );
        _requireOk(retryResponse, 'PUT retry');
      }
      return false;
    }

    // FK violation: child references a parent row gone from server.
    // Discard — modifying the local DB would generate new CRUD entries.
    if (responseBody.contains('"23503"') && _childTables.contains(table)) {
      _log.warning('Discarding orphaned $table row ${op.id}');
      return true;
    }

    throw Exception('PostgREST PUT conflict: 409 $responseBody');
  }

  Future<bool> _patchExerciseByName(
    Map<String, dynamic>? data,
    http.Client client,
  ) async {
    final name = data?['name'] as String?;
    if (name == null) return false;
    _log.info('Exercise "$name" exists with different ID, patching by name');
    final response = await client.patch(
      Uri.parse('$_baseUrl/exercises?name=eq.${Uri.encodeComponent(name)}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    _requireOk(response, 'PATCH exercise by name');
    return false;
  }

  Future<void> _patch(CrudEntry op, http.Client client) async {
    final response = await client.patch(
      Uri.parse('$_baseUrl/${op.table}?id=eq.${op.id}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(op.opData),
    );
    _requireOk(response, 'PATCH');
  }

  Future<void> _delete(CrudEntry op, http.Client client) async {
    final response = await client.delete(
      Uri.parse('$_baseUrl/${op.table}?id=eq.${op.id}'),
    );
    _requireOk(response, 'DELETE');
  }

  void _requireOk(http.Response response, String verb) {
    if (response.statusCode >= 400) {
      throw Exception(
        'PostgREST $verb error: ${response.statusCode} ${response.body}',
      );
    }
  }
}
