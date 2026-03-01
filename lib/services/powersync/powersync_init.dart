import 'dart:convert';
import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

import 'powersync_schema.dart';

final _log = Logger('PowerSyncInit');

// Server configuration from .env
String get _powersyncUrl => dotenv.env['POWERSYNC_URL'] ?? '';
String get _postgrestUrl => dotenv.env['POSTGREST_URL'] ?? '';
String get _jwtSecret => dotenv.env['POWERSYNC_JWT_SECRET'] ?? '';

/// Initialize PowerSync database.
Future<PowerSyncDatabase> initPowerSync() async {
  _log.info('Starting PowerSync initialization...');

  // Log environment configuration (without secrets)
  _log.info('PowerSync URL: $_powersyncUrl');
  _log.info('PostgREST URL: $_postgrestUrl');
  _log.info('JWT Secret configured: ${_jwtSecret.isNotEmpty}');

  if (_powersyncUrl.isEmpty || _postgrestUrl.isEmpty || _jwtSecret.isEmpty) {
    final error =
        'Missing required .env configuration. '
        'POWERSYNC_URL=${_powersyncUrl.isEmpty ? "MISSING" : "OK"}, '
        'POSTGREST_URL=${_postgrestUrl.isEmpty ? "MISSING" : "OK"}, '
        'POWERSYNC_JWT_SECRET=${_jwtSecret.isEmpty ? "MISSING" : "OK"}';
    _log.severe(error);
    throw StateError(error);
  }

  final dbPath = await getDatabasePath();
  _log.info('Database path: $dbPath');

  // Check if directory exists
  final dbDir = Directory(p.dirname(dbPath));
  if (!dbDir.existsSync()) {
    _log.info('Creating database directory: ${dbDir.path}');
    dbDir.createSync(recursive: true);
  }

  // Create a logger that forwards to debugPrint for visibility
  final logger = Logger.detached('PowerSync');
  logger.level = kDebugMode ? Level.INFO : Level.WARNING;
  logger.onRecord.listen((record) {
    debugPrint(
      '[${record.level.name}] ${record.loggerName}: ${record.message}',
    );
    if (record.error != null) {
      debugPrint('  Error: ${record.error}');
    }
    if (record.stackTrace != null) {
      debugPrint('  Stack: ${record.stackTrace}');
    }
  });

  try {
    _log.info('Creating PowerSyncDatabase instance...');
    final db = PowerSyncDatabase(schema: schema, path: dbPath, logger: logger);

    _log.info('Initializing database...');
    await db.initialize();
    _log.info('Database initialized successfully');

    await _purgeNonDeterministicRunData(db);
    await _purgeOrphanedRunChildCrudEntries(db);
    await _reconcileServerRunIds(db, _postgrestUrl);

    _log.info('Connecting to PowerSync service...');
    await reconnectPowerSync(db);
    _log.info('PowerSync connection established');

    return db;
  } catch (e, stack) {
    _log.severe('PowerSync initialization failed', e, stack);
    debugPrint('[PowerSync] FATAL: Initialization failed');
    debugPrint('[PowerSync] Error: $e');
    debugPrint('[PowerSync] Stack trace:\n$stack');
    debugPrint('[PowerSync] Database path: $dbPath');
    debugPrint(
      '[PowerSync] Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
    );
    rethrow;
  }
}

/// Finds all locally-stored runs whose id doesn't match the deterministic UUID
/// expected for their external_workout_id, and deletes them (plus their child
/// rows) from the local database. This queues a DELETE CRUD op for each stale
/// run, which PowerSync uploads to the server; the server then cascade-deletes
/// the associated route points and heart rate samples via FK constraints.
///
/// After this runs, only deterministic-UUID runs remain, so future imports and
/// server syncs converge on the same id and no longer produce FK violations.
Future<void> _purgeNonDeterministicRunData(PowerSyncDatabase db) async {
  try {
    final allRunRows = await db.execute(
      'SELECT id, external_workout_id FROM runs',
    );
    if (allRunRows.isEmpty) return;

    final uuid = Uuid();
    final namespace = Namespace.url.value;
    final staleRunIds = <String>[];

    for (final row in allRunRows) {
      final runId = row['id'] as String;
      final externalId = row['external_workout_id'] as String?;
      if (externalId == null) continue;
      final expectedId = uuid.v5(namespace, 'apple-health-run:$externalId');
      if (runId != expectedId) {
        staleRunIds.add(runId);
      }
    }

    if (staleRunIds.isEmpty) return;

    _log.info(
      'Purging ${staleRunIds.length} runs with non-deterministic UUIDs...',
    );

    // Purge any pre-existing CRUD entries for stale runs and their children
    // so we start with a clean slate before the local deletes below.
    // PowerSync's ps_crud JSON uses "table" (not "type") for the table name.
    final placeholders = List.filled(staleRunIds.length, '?').join(', ');
    await db.execute('''
      DELETE FROM ps_crud
      WHERE (json_extract(data, '\$.type') = 'runs'
               AND json_extract(data, '\$.id') IN ($placeholders))
         OR json_extract(data, '\$.data.run_id') IN ($placeholders)
    ''', [...staleRunIds, ...staleRunIds]);

    // Record the current high-water mark of ps_crud so we can identify CRUD
    // entries that are created by our child-row deletes below.
    final hwmRows = await db.execute(
      'SELECT COALESCE(MAX(id), 0) AS hwm FROM ps_crud',
    );
    final crudHwm = hwmRows.first['hwm'] as int;

    // Delete child rows locally. PowerSync will queue a DELETE CRUD entry per
    // row, but we'll strip those out immediately after (the server handles
    // cleanup via FK cascade when the run DELETE is uploaded).
    for (final runId in staleRunIds) {
      await db.execute(
        'DELETE FROM run_route_points WHERE run_id = ?',
        [runId],
      );
      await db.execute(
        'DELETE FROM run_heart_rate_samples WHERE run_id = ?',
        [runId],
      );
    }

    // Strip the freshly-queued child DELETE entries — redundant once the
    // run-level DELETE cascades on the server.
    await db.execute('''
      DELETE FROM ps_crud
      WHERE id > ?
        AND json_extract(data, '\$.type')
              IN ('run_route_points', 'run_heart_rate_samples')
    ''', [crudHwm]);

    // Delete the runs themselves. These DELETE CRUD entries stay in the queue
    // and are uploaded to the server, which cascade-deletes child rows there.
    for (final runId in staleRunIds) {
      await db.execute('DELETE FROM runs WHERE id = ?', [runId]);
    }

    _log.info(
      'Purged ${staleRunIds.length} stale runs. '
      'Server will cascade-delete their route points and heart rate samples.',
    );
  } catch (e) {
    _log.warning('Could not purge non-deterministic run data: $e');
  }
}

/// Ensures the server has every local run stored under its deterministic UUID.
///
/// If a run with the same external_workout_id exists on the server under a
/// *different* (old random) UUID, this function deletes it (which cascades to
/// its server-side route_points and heart_rate_samples) and re-inserts the run
/// with the correct deterministic UUID. After this, the child-row CRUD entries
/// already in the upload queue can succeed their FK checks.
Future<void> _reconcileServerRunIds(
  PowerSyncDatabase db,
  String postgrestUrl,
) async {
  try {
    final localRunRows = await db.execute('SELECT * FROM runs');
    if (localRunRows.isEmpty) return;

    final uuid = Uuid();
    final namespace = Namespace.url.value;
    var reconciled = 0;

    for (final row in localRunRows) {
      final localId = row['id'] as String;
      final externalId = row['external_workout_id'] as String?;
      if (externalId == null) continue;

      final expectedId = uuid.v5(namespace, 'apple-health-run:$externalId');
      if (localId != expectedId) continue; // Non-deterministic — skip.

      // Delete any server row with the same external_workout_id but a
      // different (old random) id. The `id=neq.` filter ensures we don't
      // touch the row if it's already correct.
      await http.delete(
        Uri.parse(
          '$postgrestUrl/runs'
          '?external_workout_id=eq.$externalId'
          '&id=neq.$localId',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      // Upsert the run with the deterministic UUID.
      final response = await http.post(
        Uri.parse('$postgrestUrl/runs'),
        headers: {
          'Content-Type': 'application/json',
          'Prefer': 'resolution=merge-duplicates',
        },
        body: jsonEncode({...row, 'id': localId}),
      );
      if (response.statusCode < 400) {
        reconciled++;
      } else {
        _log.warning(
          'Could not reconcile run $localId '
          '(external: $externalId): ${response.statusCode} ${response.body}',
        );
      }
    }

    if (reconciled > 0) {
      _log.info(
        'Reconciled $reconciled runs on server to deterministic UUIDs.',
      );
    }
  } catch (e) {
    _log.warning('Could not reconcile server run IDs: $e');
  }
}

/// Bulk-removes CRUD queue entries for run child tables whose run_id no longer
/// exists in the local runs table. This covers both PUT entries (which carry a
/// run_id in their data payload) and DELETE entries (which have no data
/// payload, so json_extract returns NULL — also safe to drop since the server
/// handles cascade-deletes when the parent run DELETE is uploaded).
/// Note: PowerSync's ps_crud JSON uses "table" (not "type") for the table name.
Future<void> _purgeOrphanedRunChildCrudEntries(PowerSyncDatabase db) async {
  try {
    // ps_crud JSON uses "type" for the table name and "data.run_id" for the
    // run foreign key (confirmed from live row inspection).
    final countRows = await db.execute('''
      SELECT COUNT(*) AS cnt FROM ps_crud
      WHERE json_extract(data, '\$.type') IN ('run_route_points', 'run_heart_rate_samples')
        AND (
          json_extract(data, '\$.data.run_id') IS NULL
          OR json_extract(data, '\$.data.run_id') NOT IN (SELECT id FROM runs)
        )
    ''');
    final orphanCount = countRows.first['cnt'] as int? ?? 0;
    if (orphanCount > 0) {
      await db.execute('''
        DELETE FROM ps_crud
        WHERE json_extract(data, '\$.type') IN ('run_route_points', 'run_heart_rate_samples')
          AND (
            json_extract(data, '\$.data.run_id') IS NULL
            OR json_extract(data, '\$.data.run_id') NOT IN (SELECT id FROM runs)
          )
      ''');
      _log.info('Purged $orphanCount orphaned run child CRUD entries.');
    }
  } catch (e) {
    _log.warning('Could not purge orphaned run CRUD entries: $e');
  }
}

/// Reconnect to PowerSync (creates fresh connector).
Future<void> reconnectPowerSync(PowerSyncDatabase db) async {
  await db.connect(
    connector: WorkoutsBackendConnector(_powersyncUrl, _postgrestUrl),
  );
}

Future<String> getDatabasePath() async {
  final dir = await getApplicationDocumentsDirectory();
  return p.join(dir.path, 'powersync.db');
}

/// Generate a JWT token for PowerSync authentication.
String generatePowerSyncToken({String userId = 'default'}) {
  final jwt = JWT(
    {
      'sub': userId,
      'aud': 'powersync',
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'exp':
          DateTime.now()
              .add(const Duration(hours: 24))
              .millisecondsSinceEpoch ~/
          1000,
    },
    header: {'kid': 'workouts-dev-key'},
  );

  return jwt.sign(SecretKey(_jwtSecret), algorithm: JWTAlgorithm.HS256);
}

/// Backend connector for PowerSync.
///
/// Handles authentication and write-back to Postgres via PostgREST.
class WorkoutsBackendConnector extends PowerSyncBackendConnector {
  final String powersyncUrl;
  final String postgrestUrl;

  WorkoutsBackendConnector(this.powersyncUrl, this.postgrestUrl);

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    final token = generatePowerSyncToken();
    return PowerSyncCredentials(
      endpoint: powersyncUrl,
      token: token,
      userId: 'default',
    );
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final batch = await database.getCrudBatch(limit: 1000);
    if (batch == null) return;

    final totalInBatch = batch.crud.length;
    final remainingRows = await database.execute(
      'SELECT COUNT(*) AS cnt FROM ps_crud',
    );
    final totalRemaining = remainingRows.first['cnt'] as int? ?? 0;

    _log.info(
      'Processing upload batch: $totalInBatch ops in this batch, '
      '$totalRemaining total remaining in queue.',
    );

    var uploaded = 0;
    var discarded = 0;
    for (final op in batch.crud) {
      final wasDiscarded = await _uploadOperation(op);
      if (wasDiscarded) {
        discarded++;
      } else {
        uploaded++;
      }
    }

    await batch.complete();

    _log.info(
      'Batch complete: $uploaded uploaded, $discarded discarded. '
      '${totalRemaining - totalInBatch} ops still queued.',
    );
  }

  static const _runChildTables = {'run_route_points', 'run_heart_rate_samples'};

  // Natural unique keys for child tables, used to resolve conflicts when the
  // server already has a row for the same logical entity under a different PK.
  static const _childTableConflictColumns = {
    'run_route_points': 'run_id,point_index',
    'run_heart_rate_samples': 'run_id,timestamp',
  };

  /// Returns true if the entry was discarded (not actually uploaded).
  Future<bool> _uploadOperation(CrudEntry op) async {
    final table = op.table;
    final data = op.opData;

    try {
      switch (op.op) {
        case UpdateType.put:
          final conflictColumns = _childTableConflictColumns[table];
          final putUrl = conflictColumns != null
              ? '$postgrestUrl/$table?on_conflict=$conflictColumns'
              : '$postgrestUrl/$table';
          final response = await http.post(
            Uri.parse(putUrl),
            headers: {
              'Content-Type': 'application/json',
              'Prefer': 'resolution=merge-duplicates',
            },
            body: jsonEncode({...?data, 'id': op.id}),
          );
          if (response.statusCode == 409) {
            final body = response.body;
            // Duplicate external_workout_id: the server has the run under an
            // old random UUID. Delete the conflicting row (which cascades to
            // its route_points and heart_rate_samples on the server) and
            // reinsert with the correct deterministic UUID so subsequent
            // child-row uploads can pass their FK checks.
            if (body.contains('"23505"') && table == 'runs') {
              final externalId = data?['external_workout_id'] as String?;
              if (externalId != null) {
                await http.delete(
                  Uri.parse(
                    '$postgrestUrl/$table?external_workout_id=eq.$externalId',
                  ),
                  headers: {'Content-Type': 'application/json'},
                );
                final retryResponse = await http.post(
                  Uri.parse('$postgrestUrl/$table'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Prefer': 'resolution=merge-duplicates',
                  },
                  body: jsonEncode({...?data, 'id': op.id}),
                );
                if (retryResponse.statusCode >= 400) {
                  throw Exception(
                    'PostgREST error on retry after DELETE: '
                    '${retryResponse.statusCode} ${retryResponse.body}',
                  );
                }
              }
            } else if (body.contains('"23503"') &&
                _runChildTables.contains(table)) {
              // FK violation: this child row references an old random run_id
              // that no longer exists on the server. Discard the CRUD entry
              // without touching local state — PowerSync's next checkpoint sync
              // will reconcile. (Modifying the DB here would itself create new
              // CRUD entries, causing an upload loop.)
              return true;
            } else {
              throw Exception('PostgREST error: ${response.statusCode} $body');
            }
          } else if (response.statusCode >= 400) {
            throw Exception(
              'PostgREST error: ${response.statusCode} ${response.body}',
            );
          }

        case UpdateType.patch:
          await http.patch(
            Uri.parse('$postgrestUrl/$table?id=eq.${op.id}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          );

        case UpdateType.delete:
          await http.delete(Uri.parse('$postgrestUrl/$table?id=eq.${op.id}'));
      }
    } catch (e) {
      _log.severe('Upload error for $table ${op.id}: $e');
      rethrow;
    }
    return false;
  }
}
