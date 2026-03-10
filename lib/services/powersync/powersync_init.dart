import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';
import 'powersync_connector.dart';
import 'powersync_schema.dart';

final _log = Logger('PowerSyncInit');

String get _powersyncUrl => dotenv.env['POWERSYNC_URL'] ?? '';
String get _postgrestUrl => dotenv.env['POSTGREST_URL'] ?? '';
String get _jwtSecret => dotenv.env['POWERSYNC_JWT_SECRET'] ?? '';

Future<PowerSyncDatabase> initPowerSync() async {
  _log.info('Starting PowerSync initialization...');
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

  final dbDir = Directory(p.dirname(dbPath));
  if (!dbDir.existsSync()) {
    _log.info('Creating database directory: ${dbDir.path}');
    dbDir.createSync(recursive: true);
  }

  final logger = Logger.detached('PowerSync');
  logger.level = kDebugMode ? Level.INFO : Level.WARNING;
  logger.onRecord.listen((record) {
    developer.log(
      '[${record.level.name}] ${record.loggerName}: ${record.message}',
      name: record.loggerName,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  });

  try {
    _log.info('Creating PowerSyncDatabase instance...');
    final db = PowerSyncDatabase(schema: schema, path: dbPath, logger: logger);

    _log.info('Initializing database...');
    await db.initialize();
    _log.info('Database initialized successfully');

    await _purgeOrphanedCardioChildCrudEntries(db);

    _log.info('Connecting to PowerSync service...');
    await reconnectPowerSync(db);
    _log.info('PowerSync connection established');

    return db;
  } catch (e, stack) {
    _log.severe('PowerSync initialization failed at $dbPath', e, stack);
    rethrow;
  }
}

Future<void> reconnectPowerSync(PowerSyncDatabase db) async {
  await db.connect(
    connector: WorkoutsBackendConnector(_powersyncUrl, _postgrestUrl),
  );
}

Future<String> getDatabasePath() async {
  final dir = await getApplicationDocumentsDirectory();
  return p.join(dir.path, 'powersync.db');
}

/// Bulk-removes CRUD queue entries for cardio child tables whose workout_id
/// no longer exists in the local cardio_workouts table.
Future<void> _purgeOrphanedCardioChildCrudEntries(PowerSyncDatabase db) async {
  try {
    final countRows = await db.execute('''
      SELECT COUNT(*) AS cnt FROM ps_crud
      WHERE json_extract(data, '\$.type') IN ('cardio_route_points', 'cardio_heart_rate_samples')
        AND (
          json_extract(data, '\$.data.workout_id') IS NULL
          OR json_extract(data, '\$.data.workout_id') NOT IN (SELECT id FROM cardio_workouts)
        )
    ''');
    final orphanCount = countRows.first['cnt'] as int? ?? 0;
    if (orphanCount > 0) {
      await db.execute('''
        DELETE FROM ps_crud
        WHERE json_extract(data, '\$.type') IN ('cardio_route_points', 'cardio_heart_rate_samples')
          AND (
            json_extract(data, '\$.data.workout_id') IS NULL
            OR json_extract(data, '\$.data.workout_id') NOT IN (SELECT id FROM cardio_workouts)
          )
      ''');
      _log.info('Purged $orphanCount orphaned cardio child CRUD entries.');
    }
  } catch (e) {
    _log.warning('Could not purge orphaned cardio CRUD entries: $e');
  }
}
