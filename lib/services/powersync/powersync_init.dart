import 'dart:io';

import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'powersync_connector.dart';
import 'powersync_schema.dart';

const _log = ELogger('PowerSyncInit');
const _powerSyncDatabasePathPreferenceKey = 'powersync_database_path';

String get _powersyncUrl => dotenv.env['POWERSYNC_URL'] ?? '';
String get _postgrestUrl => dotenv.env['POSTGREST_URL'] ?? '';
String get _jwtSecret => dotenv.env['POWERSYNC_JWT_SECRET'] ?? '';

Future<PowerSyncDatabase> initPowerSync({
  required SharedPreferences sharedPreferences,
}) async {
  if (_powersyncUrl.isEmpty || _postgrestUrl.isEmpty || _jwtSecret.isEmpty) {
    final errorMessage =
        'Missing required .env configuration. '
        'POWERSYNC_URL=${_powersyncUrl.isEmpty ? "MISSING" : "OK"}, '
        'POSTGREST_URL=${_postgrestUrl.isEmpty ? "MISSING" : "OK"}, '
        'POWERSYNC_JWT_SECRET=${_jwtSecret.isEmpty ? "MISSING" : "OK"}';
    _log.error(errorMessage);
    throw StateError(errorMessage);
  }

  final dbPath = await getDatabasePath(
    sharedPreferences: sharedPreferences,
  );

  final dbDir = Directory(p.dirname(dbPath));
  if (!dbDir.existsSync()) {
    _log.log('Creating database directory: ${dbDir.path}');
    dbDir.createSync(recursive: true);
  }

  // Detached logger for PowerSync's internal messages — must remain a
  // logging.Logger since it's passed to PowerSyncDatabase.
  final powerSyncInternalLog = ELogger('PowerSync');
  final powerSyncLogger = Logger.detached('PowerSync');
  powerSyncLogger.level = kDebugMode ? Level.INFO : Level.WARNING;
  powerSyncLogger.onRecord.listen((record) {
    if (record.level >= Level.SEVERE) {
      powerSyncInternalLog.error(record.message, record.error, record.stackTrace);
    } else if (record.level >= Level.WARNING) {
      powerSyncInternalLog.warn(record.message);
    } else {
      powerSyncInternalLog.log(record.message);
    }
  });

  try {
    final powerSyncDatabase = PowerSyncDatabase(
      schema: schema,
      path: dbPath,
      logger: powerSyncLogger,
    );

    await powerSyncDatabase.initialize();

    await _purgeOrphanedCardioChildCrudEntries(powerSyncDatabase);

    await reconnectPowerSync(powerSyncDatabase);

    if (kDebugMode) _subscribeDownloadTableLogs(powerSyncDatabase);

    return powerSyncDatabase;
  } catch (error, stackTrace) {
    _log.error('PowerSync initialization failed at $dbPath', error, stackTrace);
    rethrow;
  }
}

Future<void> reconnectPowerSync(PowerSyncDatabase powerSyncDatabase) async {
  await powerSyncDatabase.connect(
    connector: WorkoutsBackendConnector(_powersyncUrl, _postgrestUrl),
  );
}

/// Subscribes to download cycles and logs which tables were written.
///
/// Each time PowerSync finishes a download phase, emits a single line like:
///   ⬇️ Download wrote: exercises, workout_templates
///
/// This makes it easy to spot when workout_templates (or any other table) is
/// being re-synced from the server — which is the signal that a server-side
/// record is overwriting a local delete.
void _subscribeDownloadTableLogs(PowerSyncDatabase powerSyncDatabase) {
  final tablesInCurrentDownload = <String>{};
  var wasDownloading = false;

  powerSyncDatabase.updates.listen((notification) {
    if (wasDownloading) tablesInCurrentDownload.addAll(notification.tables);
  });

  powerSyncDatabase.statusStream.listen((status) {
    if (status.downloading && !wasDownloading) {
      tablesInCurrentDownload.clear();
      wasDownloading = true;
    } else if (!status.downloading && wasDownloading) {
      wasDownloading = false;
      if (tablesInCurrentDownload.isNotEmpty) {
        final sorted = tablesInCurrentDownload.toList()..sort();
        _log.log('⬇️ Synced tables: ${sorted.join(', ')}');
      } else {
        _log.log('⬇️ Sync complete (no data written)');
      }
      tablesInCurrentDownload.clear();
    }
  });
}

Future<String> getDatabasePath({
  required SharedPreferences sharedPreferences,
}) async {
  final cachedDatabasePath =
      sharedPreferences.getString(_powerSyncDatabasePathPreferenceKey);
  if (cachedDatabasePath != null) {
    final cachedDatabaseDirectory = Directory(p.dirname(cachedDatabasePath));
    if (cachedDatabaseDirectory.existsSync()) {
      _log.log('Database path (from cache): $cachedDatabasePath');
      return cachedDatabasePath;
    }
    _log.log(
      'Cached database path directory no longer exists, re-resolving: '
      '$cachedDatabasePath',
    );
  }
  final documentsDirectory = await getApplicationDocumentsDirectory();
  final databasePath = p.join(documentsDirectory.path, 'powersync.db');
  await sharedPreferences.setString(
    _powerSyncDatabasePathPreferenceKey,
    databasePath,
  );
  _log.log('Database path (resolved): $databasePath');
  return databasePath;
}

/// Bulk-removes CRUD queue entries for cardio child tables whose workout_id
/// no longer exists in the local cardio_workouts table.
Future<void> _purgeOrphanedCardioChildCrudEntries(
  PowerSyncDatabase powerSyncDatabase,
) async {
  try {
    final countRows = await powerSyncDatabase.execute('''
      SELECT COUNT(*) AS cnt FROM ps_crud
      WHERE json_extract(data, '\$.type') IN ('cardio_route_points', 'cardio_heart_rate_samples')
        AND (
          json_extract(data, '\$.data.workout_id') IS NULL
          OR json_extract(data, '\$.data.workout_id') NOT IN (SELECT id FROM cardio_workouts)
        )
    ''');
    final orphanCount = countRows.first['cnt'] as int? ?? 0;
    if (orphanCount > 0) {
      await powerSyncDatabase.execute('''
        DELETE FROM ps_crud
        WHERE json_extract(data, '\$.type') IN ('cardio_route_points', 'cardio_heart_rate_samples')
          AND (
            json_extract(data, '\$.data.workout_id') IS NULL
            OR json_extract(data, '\$.data.workout_id') NOT IN (SELECT id FROM cardio_workouts)
          )
      ''');
      _log.log('Removed $orphanCount stale upload entries for deleted cardio workouts.');
    }
  } catch (error) {
    _log.warn('Could not purge orphaned cardio CRUD entries: $error');
  }
}
