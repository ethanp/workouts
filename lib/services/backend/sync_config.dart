import 'dart:convert';
import 'dart:io';

import 'package:ethan_sync/ethan_sync.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workouts/services/powersync/powersync_schema.dart';
import 'package:workouts/utils/error_bus.dart';

const _log = ELogger('WorkoutsSync');

const _powersyncPort = 8081;
const _postgrestPort = 3001;
const _databasePathKey = 'powersync_database_path';

/// Builds the workouts app's [SyncConfig] for `ethan_sync`. This is the single
/// place that knows the workouts schema, FK graph, conflict policy, ports,
/// secrets, and startup hooks; the shared package supplies everything else.
SyncConfig buildWorkoutsSyncConfig(SharedPreferences preferences) {
  return SyncConfig(
    hostResolution: HostResolutionSettings(
      candidates: _hostCandidates(),
      probePort: _postgrestPort,
      unreachablePolicy: const ParkOnLastCandidatePolicy(),
    ),
    ports: const SyncPorts(powersync: _powersyncPort, postgrest: _postgrestPort),
    jwtCredentials: PowerSyncJwtCredentials(
      secret: _jwtSecret(),
      keyId: 'workouts-dev-key',
    ),
    schema: schema,
    databasePath: () => _resolveDatabasePath(preferences),
    upload: UploadSettings(
      strategy: TieredBatchUploadStrategy(dependencies: _fkDependencies),
      conflictColumns: _conflictColumns,
      conflictResolver: const WorkoutsConflictResolver(),
      crudBatchLimit: 1000,
    ),
    startupHooks: [
      _requireJwtSecret,
      _purgeOrphanedCardioChildCrudEntries,
      if (kDebugMode) _logDownloadedTables,
    ],
    onSyncError: errorBus.add,
  );
}

String _jwtSecret() => dotenv.env['POWERSYNC_JWT_SECRET'] ?? '';

List<String> _hostCandidates() {
  final lan = dotenv.env['SERVER_HOST_LAN'];
  final tailscale = dotenv.env['SERVER_HOST_TAILSCALE'];
  final candidates = [
    if (lan != null && lan.isNotEmpty) lan,
    if (tailscale != null && tailscale.isNotEmpty && tailscale != lan) tailscale,
  ];
  if (candidates.isEmpty) {
    throw StateError(
      'No SERVER_HOST_LAN or SERVER_HOST_TAILSCALE configured in .env',
    );
  }
  return candidates;
}

Future<String> _resolveDatabasePath(SharedPreferences preferences) async {
  final cachedPath = preferences.getString(_databasePathKey);
  if (cachedPath != null && Directory(p.dirname(cachedPath)).existsSync()) {
    return cachedPath;
  }
  final documentsDirectory = await getApplicationDocumentsDirectory();
  final path = p.join(documentsDirectory.path, 'powersync.db');
  await preferences.setString(_databasePathKey, path);
  return path;
}

Future<void> _requireJwtSecret(PowerSyncDatabase database) async {
  if (_jwtSecret().isEmpty) {
    throw StateError('Missing POWERSYNC_JWT_SECRET in .env');
  }
}

/// FK dependency graph (table -> tables it references), derived from init.sql.
/// Drives FK-safe upload ordering in [TieredBatchUploadStrategy].
const _fkDependencies = <String, Set<String>>{
  'exercises': {},
  'workout_templates': {},
  'fitness_goals': {},
  'cardio_workouts': {},
  'training_influences': {},
  'workout_blocks': {'workout_templates'},
  'sessions': {'workout_templates'},
  'background_notes': {'fitness_goals'},
  'cardio_route_points': {'cardio_workouts'},
  'cardio_heart_rate_samples': {'cardio_workouts'},
  'cardio_best_efforts': {'cardio_workouts'},
  'workout_block_exercises': {'workout_blocks', 'exercises'},
  'session_blocks': {'sessions'},
  'session_notes': {'sessions'},
  'heart_rate_samples': {'sessions'},
  'session_block_exercises': {'session_blocks', 'exercises'},
  'session_set_logs': {'session_blocks', 'exercises'},
};

/// Non-PK unique constraints PostgREST needs for `on_conflict` merge-duplicates.
/// Must match the UNIQUE constraints in init.sql. `exercises` is deliberately
/// excluded — see [WorkoutsConflictResolver].
const _conflictColumns = <String, String>{
  'workout_blocks': 'template_id,block_index',
  'workout_block_exercises': 'block_id,exercise_id,exercise_index',
  'session_blocks': 'session_id,block_index',
  'session_block_exercises': 'block_id,exercise_id,exercise_index',
  'session_set_logs': 'block_id,exercise_id,set_index',
  'cardio_route_points': 'workout_id,point_index',
  'cardio_heart_rate_samples': 'workout_id,timestamp',
  'cardio_best_efforts': 'workout_id,distance_meters',
};

/// Resolves the workouts-specific PostgREST 409 conflicts: re-homing exercises
/// by name after a reinstall, recovering cardio rows whose `external_workout_id`
/// collides, and discarding orphaned child rows.
class WorkoutsConflictResolver extends ConflictResolver {
  const WorkoutsConflictResolver();

  // Child tables: if the parent row is gone server-side, discard the op rather
  // than retrying forever.
  static const _childTables = {
    'cardio_route_points',
    'cardio_heart_rate_samples',
    'cardio_best_efforts',
    'workout_blocks',
    'workout_block_exercises',
    'session_blocks',
    'session_block_exercises',
    'session_set_logs',
    'session_notes',
    'background_notes',
    'heart_rate_samples',
  };

  @override
  Future<ConflictOutcome> resolve(PostgrestConflict conflict) async {
    final table = conflict.op.table;

    if (table == 'exercises' &&
        (conflict.isUniqueViolation || conflict.isForeignKeyViolation)) {
      await _patchExerciseByName(conflict);
      return ConflictOutcome.resolved;
    }

    if (table == 'cardio_workouts' && conflict.isUniqueViolation) {
      await _reinsertCardioWorkout(conflict);
      return ConflictOutcome.resolved;
    }

    if (conflict.isForeignKeyViolation && _childTables.contains(table)) {
      _log.warn('Discarding orphaned $table row ${conflict.op.id}');
      return ConflictOutcome.discarded;
    }

    throw Exception('PostgREST PUT conflict: 409 ${conflict.responseBody}');
  }

  /// Patches the existing server exercise matched by name, leaving its ID
  /// untouched so FK references stay valid. Needed after reinstall (new UUIDs,
  /// same names).
  Future<void> _patchExerciseByName(PostgrestConflict conflict) async {
    final name = conflict.data?['name'] as String?;
    if (name == null) return;
    _log.log('Exercise "$name" exists with different ID, patching by name');
    final response = await conflict.client.patch(
      Uri.parse(
        '${conflict.postgrestUrl}/exercises?name=eq.${Uri.encodeComponent(name)}',
      ),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(conflict.data),
    );
    _requireOk(response, 'PATCH exercise by name');
  }

  /// Deletes the server row whose `external_workout_id` collides, then
  /// re-inserts with the local UUID. Needed after reinstall when the source ID
  /// is the same but the local UUID changed.
  Future<void> _reinsertCardioWorkout(PostgrestConflict conflict) async {
    final externalId = conflict.data?['external_workout_id'] as String?;
    if (externalId == null) return;
    final table = conflict.op.table;
    await conflict.client.delete(
      Uri.parse('${conflict.postgrestUrl}/$table?external_workout_id=eq.$externalId'),
      headers: const {'Content-Type': 'application/json'},
    );
    final response = await conflict.client.post(
      Uri.parse('${conflict.postgrestUrl}/$table'),
      headers: const {
        'Content-Type': 'application/json',
        'Prefer': 'resolution=merge-duplicates',
      },
      body: jsonEncode({...?conflict.data, 'id': conflict.op.id}),
    );
    _requireOk(response, 'PUT retry');
  }

  static void _requireOk(http.Response response, String verb) {
    if (response.statusCode >= 400) {
      throw Exception(
        'PostgREST $verb error: ${response.statusCode} ${response.body}',
      );
    }
  }
}

/// Bulk-removes CRUD queue entries for cardio child tables whose `workout_id`
/// no longer exists locally, so a deleted cardio workout doesn't leave
/// un-uploadable orphans wedged in the queue.
Future<void> _purgeOrphanedCardioChildCrudEntries(
  PowerSyncDatabase database,
) async {
  const orphanFilter = '''
    json_extract(data, '\$.type') IN ('cardio_route_points', 'cardio_heart_rate_samples')
      AND (
        json_extract(data, '\$.data.workout_id') IS NULL
        OR json_extract(data, '\$.data.workout_id') NOT IN (SELECT id FROM cardio_workouts)
      )
  ''';
  try {
    final countRows = await database.execute(
      'SELECT COUNT(*) AS cnt FROM ps_crud WHERE $orphanFilter',
    );
    final orphanCount = countRows.first['cnt'] as int? ?? 0;
    if (orphanCount == 0) return;
    await database.execute('DELETE FROM ps_crud WHERE $orphanFilter');
    _log.log('Removed $orphanCount stale upload entries for deleted cardio workouts.');
  } catch (error) {
    _log.warn('Could not purge orphaned cardio CRUD entries: $error');
  }
}

/// Logs which tables each download cycle writes — the signal that a server
/// record is overwriting a local delete.
Future<void> _logDownloadedTables(PowerSyncDatabase database) async {
  final tablesInDownload = <String>{};
  var wasDownloading = false;

  database.updates.listen((notification) {
    if (wasDownloading) tablesInDownload.addAll(notification.tables);
  });

  database.statusStream.listen((status) {
    if (status.downloading && !wasDownloading) {
      tablesInDownload.clear();
      wasDownloading = true;
    } else if (!status.downloading && wasDownloading) {
      wasDownloading = false;
      if (tablesInDownload.isEmpty) {
        _log.log('⬇️ Sync complete (no data written)');
      } else {
        final sorted = tablesInDownload.toList()..sort();
        _log.log('⬇️ Synced tables: ${sorted.join(', ')}');
      }
      tablesInDownload.clear();
    }
  });
}
